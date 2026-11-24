// Kheyrukum Free-Tier (Firebase Spark Plan) Push Notification Dispatcher
// Sends closed-app push alerts via Firebase Cloud Messaging HTTP v1 API.
//
// Required Supabase Edge Function Secrets:
//   - FIREBASE_SERVICE_ACCOUNT_JSON : JSON (or base64 JSON) of Firebase Service Account key
//   - PUSH_WEBHOOK_SECRET           : Random shared secret for DB Webhooks / pg_cron callers
// Automatically injected by Supabase Runtime:
//   - SUPABASE_URL
//   - SUPABASE_SERVICE_ROLE_KEY

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const TOKEN_URL = "https://oauth2.googleapis.com/token";
const DEFAULT_CHANNEL_ID = "kheyrukum_channel";
const DEFAULT_ANDROID_ICON = "ic_stat_kheyrukum";
const PAGE_SIZE = 1000;
const RPC_BATCH_SIZE = 500;
const FCM_CONCURRENCY = 20;
const MAX_NON_ADMIN_RECIPIENTS = 50;
const UUID_RE =
  /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-webhook-secret",
};

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

interface TokenRow {
  user_id: string;
  device_token: string;
  device_type?: string;
  preferred_language?: string;
}

// Module-scoped OAuth2 token cache reused across warm Edge Function invocations
let cachedAccessToken: string | null = null;
let cachedTokenExpiryMs = 0;
let cachedTokenProjectId: string | null = null;

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function timingSafeEqualStrings(a: string, b: string): boolean {
  const aBytes = new TextEncoder().encode(a);
  const bBytes = new TextEncoder().encode(b);
  if (aBytes.length !== bBytes.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < aBytes.length; i++) {
    diff |= aBytes[i] ^ bBytes[i];
  }
  return diff === 0;
}

function base64UrlEncode(input: Uint8Array | string): string {
  const bytes =
    typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const normalized = pem.replace(/\\r\\n/g, "\n").replace(/\\n/g, "\n");
  const clean = normalized
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

function parseServiceAccount(raw: string): ServiceAccount {
  const trimmed = raw.trim();
  const jsonText = trimmed.startsWith("{") ? trimmed : atob(trimmed);
  const parsed = JSON.parse(jsonText);
  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new Error("Invalid FIREBASE_SERVICE_ACCOUNT_JSON fields.");
  }
  return parsed as ServiceAccount;
}

async function getGoogleAccessToken(sa: ServiceAccount): Promise<string> {
  const nowMs = Date.now();
  if (
    cachedAccessToken &&
    cachedTokenProjectId === sa.project_id &&
    nowMs + 60_000 < cachedTokenExpiryMs
  ) {
    return cachedAccessToken;
  }

  const now = Math.floor(nowMs / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = base64UrlEncode(
    JSON.stringify({
      iss: sa.client_email,
      scope: FCM_SCOPE,
      aud: TOKEN_URL,
      iat: now,
      exp: now + 3600,
    }),
  );

  const unsignedJwt = `${header}.${claim}`;
  const keyData = pemToArrayBuffer(sa.private_key);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedJwt),
  );

  const jwt = `${unsignedJwt}.${base64UrlEncode(new Uint8Array(signature))}`;

  const tokenResp = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResp.ok) {
    const errText = await tokenResp.text();
    throw new Error(`Google OAuth2 failed (${tokenResp.status}): ${errText}`);
  }

  const tokenData = await tokenResp.json();
  const accessToken = tokenData.access_token as string;
  const expiresInSec = Number(tokenData.expires_in ?? 3600);
  cachedAccessToken = accessToken;
  cachedTokenExpiryMs = Date.now() + expiresInSec * 1000;
  cachedTokenProjectId = sa.project_id;
  return accessToken;
}

const MONTH_FORMS: Array<[string, string, string]> = [
  ["January", "يناير", "ጃንዋሪ"],
  ["February", "فبراير", "ፌብሩዋሪ"],
  ["March", "مارس", "ማርች"],
  ["April", "أبريل", "ኤፕሪል"],
  ["May", "مايو", "ሜይ"],
  ["June", "يونيو", "ጁን"],
  ["July", "يوليو", "ጁላይ"],
  ["August", "أغسطس", "ኦገስት"],
  ["September", "سبتمبر", "ሴፕቴምበር"],
  ["October", "أكتوبر", "ኦክቶበር"],
  ["November", "نوفمبر", "ኖቬምበር"],
  ["December", "ديسمبر", "ዲሴምበር"],
];

function normLang(lang: string | undefined): "en" | "ar" | "am" {
  const lower = String(lang ?? "").trim().toLowerCase();
  if (lower === "ar" || lower === "am") return lower;
  return "en";
}

function localizeMonthLabel(raw: string, lang: "en" | "ar" | "am"): string {
  const trimmed = raw.trim();
  if (!trimmed) return trimmed;
  const idx = lang === "ar" ? 1 : lang === "am" ? 2 : 0;
  for (const forms of MONTH_FORMS) {
    for (const f of forms) {
      if (trimmed.toLowerCase().includes(f.toLowerCase())) {
        const escaped = f.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        return trimmed.replace(new RegExp(escaped, "gi"), forms[idx]);
      }
    }
  }
  return trimmed;
}

function localizeAttendanceStatus(
  status: string,
  lang: "en" | "ar" | "am",
): string {
  const s = status.trim().toLowerCase();
  if (lang === "ar") {
    if (s === "present") return "حاضر";
    if (s === "late") return "متأخر";
    if (s === "absent") return "غائب";
    if (s === "excused") return "بعذر";
    return status;
  }
  if (lang === "am") {
    if (s === "present") return "ተገኝቷል";
    if (s === "late") return "ዘግይቷል";
    if (s === "absent") return "ቀርቷል";
    if (s === "excused") return "በፈቃድ";
    return status;
  }
  if (s === "present") return "Present";
  if (s === "late") return "Late";
  if (s === "absent") return "Absent";
  if (s === "excused") return "Excused";
  return status;
}

function localizeRating(rating: string, lang: "en" | "ar" | "am"): string {
  const r = rating.trim().toLowerCase();
  if (lang === "ar") {
    if (r.includes("mumtaz") || r.includes("excellent")) return "ممتاز";
    if (r.includes("jiddan") || r.includes("very good")) return "جيد جداً";
    if (r.includes("jayyid") || r.includes("good")) return "جيد";
    if (r.includes("needs") || r.includes("revision")) return "يحتاج مراجعة";
    return rating;
  }
  if (lang === "am") {
    if (r.includes("mumtaz") || r.includes("excellent")) {
      return "ሙምታዝ (በጣም ጥሩ)";
    }
    if (r.includes("jiddan") || r.includes("very good")) {
      return "ጀይድ ጂዳን (በጣም መልካም)";
    }
    if (r.includes("jayyid") || r.includes("good")) return "ጀይድ (ጥሩ)";
    if (r.includes("needs") || r.includes("revision")) return "ክለሳ ያስፈልጋል";
    return rating;
  }
  if (r.includes("mumtaz") || r.includes("excellent")) return "Excellent";
  if (r.includes("jiddan") || r.includes("very good")) return "Very Good";
  if (r.includes("jayyid") || r.includes("good")) return "Good";
  if (r.includes("needs") || r.includes("revision")) return "Needs Revision";
  return rating;
}

function extractTemplateMeta(
  dataObj: Record<string, unknown> | undefined,
): { templateKey: string; templateParams: Record<string, string> } {
  if (!dataObj) return { templateKey: "", templateParams: {} };
  const nestedMeta =
    dataObj.metadata && typeof dataObj.metadata === "object"
      ? (dataObj.metadata as Record<string, unknown>)
      : undefined;
  const rawKey = dataObj.template_key ?? nestedMeta?.template_key ?? "";
  const templateKey = String(rawKey).trim();
  if (!templateKey) return { templateKey: "", templateParams: {} };

  const rawParams = dataObj.params ?? nestedMeta?.params;
  let parsedObj: Record<string, unknown> = dataObj;
  if (rawParams && typeof rawParams === "object") {
    parsedObj = rawParams as Record<string, unknown>;
  } else if (typeof rawParams === "string" && rawParams.trim().startsWith("{")) {
    try {
      const dec = JSON.parse(rawParams);
      if (dec && typeof dec === "object") {
        parsedObj = dec as Record<string, unknown>;
      }
    } catch {
      // Ignore malformed JSON string
    }
  }

  const templateParams: Record<string, string> = {};
  for (const [k, v] of Object.entries(parsedObj)) {
    if (v !== undefined && v !== null) {
      templateParams[k] = typeof v === "string" ? v : String(v);
    }
  }
  return { templateKey, templateParams };
}

function renderLocalizedNotification(
  templateKey: string,
  params: Record<string, string>,
  rawLang: string | undefined,
  fallbackTitle: string,
  fallbackBody: string,
): { title: string; body: string } {
  const lang = normLang(rawLang);
  const p = (k: string, def = "") => {
    const val = (params[k] ?? "").trim();
    return val.length > 0 ? val : def;
  };

  const month = localizeMonthLabel(p("month"), lang);
  const student = p(
    "student_name",
    lang === "ar" ? "الطالب" : lang === "am" ? "ተማሪው" : "Student",
  );
  const parent = p(
    "parent_name",
    lang === "ar" ? "ولي الأمر" : lang === "am" ? "ወላጅ" : "A parent",
  );
  const amount = p("amount");
  const start = p("fee_start_date");
  const reason = p("reason");
  const hwTitle = p("title");
  const surah = p("surah");
  const fromAyah = p("from_ayah", "1");
  const toAyah = p("to_ayah", "1");
  const rating = localizeRating(p("rating"), lang);
  const status = localizeAttendanceStatus(p("status"), lang);
  const date = p("date");
  const sabaq = p("sabaq");
  const halaqah = p("halaqah_name");
  const sender = p(
    "sender_name",
    lang === "ar" ? "رسالة جديدة" : lang === "am" ? "አዲስ መልእክት" : "New Message",
  );
  const msgBody = p("body");
  const duration = p("duration", "0");
  const fileName = p(
    "file_name",
    lang === "ar" ? "مستند" : lang === "am" ? "ሰነድ" : "Document",
  );
  const actor = p(
    "actor_name",
    lang === "ar" ? "مستخدم" : lang === "am" ? "ተጠቃሚ" : "A user",
  );

  switch (templateKey) {
    case "monthly_tuition_due":
      if (lang === "ar") {
        return {
          title: "رسوم دراسية جديدة مستحقة 💳",
          body: start
            ? `تم إصدار رسوم شهر ${month} للطالب ${student} بمبلغ ${amount} بر (تاريخ البدء: ${start}).`
            : `تم إصدار رسوم شهر ${month} للطالب ${student} بمبلغ ${amount} بر.`,
        };
      }
      if (lang === "am") {
        return {
          title: "አዲስ ወርሃዊ ክፍያ ተልኳል 💳",
          body: start
            ? `ለ${student} የ${month} ወር ክፍያ (${amount} ብር) ከ${start} ጀምሮ ተልኳል።`
            : `ለ${student} የ${month} ወር ክፍያ (${amount} ብር) ተልኳል።`,
        };
      }
      return {
        title: "Monthly Tuition Fee Due 💳",
        body: start
          ? `Tuition for ${month} (${amount} ETB) starting on ${start} has been issued for ${student}.`
          : `Tuition for ${month} (${amount} ETB) has been issued for ${student}.`,
      };

    case "monthly_tuition_reminder": {
      const hasStudent = p("student_name").length > 0;
      const hasAmount = amount.length > 0;
      if (lang === "ar") {
        return {
          title: "تذكير بالرسوم الشهرية 💳",
          body: hasStudent && hasAmount
            ? `تستحق رسوم الطالب ${student} لشهر ${month} بمبلغ ${amount} بر. يرجى السداد ورفع إيصال التحويل.`
            : `تستحق الرسوم الشهرية لحفظ القرآن لشهر ${month}. يرجى السداد ورفع الإيصال في قسم المدفوعات.`,
        };
      }
      if (lang === "am") {
        return {
          title: "ወርሃዊ የትምህርት ክፍያ ማስታወሻ 💳",
          body: hasStudent && hasAmount
            ? `የ${student} የ${month} ወርሃዊ ክፍያ (${amount} ብር) ደርሷል። እባክዎ ከፍለው ደረሰኙን ይስቀሉ።`
            : `የ${month} የቁርኣን ትምህርት ክፍያ ደርሷል። እባክዎ ክፍያዎን ፈጽመው በክፍያ ክፍል ደረሰኙን ይስቀሉ።`,
        };
      }
      return {
        title: "Monthly Tuition Reminder 💳",
        body: hasStudent && hasAmount
          ? `Tuition for ${student} (${month} — ${amount} ETB) is due. Please submit your payment and upload your receipt.`
          : `Monthly Quran memorization fee for ${month} is now due. Please submit your payment and upload the receipt in Payments.`,
      };
    }

    case "payment_receipt_submitted":
      if (lang === "ar") {
        return {
          title: "تم استلام إيصال دفع 📥",
          body: `رفع ${parent} إيصال رسوم شهر ${month} للمراجعة والاعتماد.`,
        };
      }
      if (lang === "am") {
        return {
          title: "የክፍያ ደረሰኝ ቀርቧል 📥",
          body: `${parent} የ${month} የትምህርት ክፍያ ደረሰኝ ለማረጋገጫ ሰቅለዋል።`,
        };
      }
      return {
        title: "Payment Receipt Submitted 📥",
        body: `${parent} uploaded a tuition receipt for ${month}.`,
      };

    case "payment_approved":
      if (lang === "ar") {
        return {
          title: "تم اعتماد الدفع ✅",
          body: `تم التحقق من دفعة الطالب ${student} لشهر ${month} واعتمادها.`,
        };
      }
      if (lang === "am") {
        return {
          title: "ክፍያው ጸድቋል ✅",
          body: `የ${student} የ${month} ወር የትምህርት ክፍያ ተረጋግጦ ጸድቋል።`,
        };
      }
      return {
        title: "Payment Approved ✅",
        body: `Your tuition payment for ${month} (${student}) has been approved.`,
      };

    case "payment_rejected":
      if (lang === "ar") {
        return {
          title: "إيصال الدفع يحتاج مراجعة ❌",
          body: `تعذر اعتماد إيصال شهر ${month}: ${reason}`,
        };
      }
      if (lang === "am") {
        return {
          title: "የክፍያ ደረሰኙ ውድቅ ተደርጓል ❌",
          body: `የ${month} ወር የክፍያ ደረሰኝ ውድቅ ተደርጓል፦ ${reason}`,
        };
      }
      return {
        title: "Payment Rejected ❌",
        body: `Your tuition receipt for ${month} was rejected: ${reason}`,
      };

    case "homework_assigned":
      if (lang === "ar") {
        return {
          title: "تم تعيين واجب جديد 📖",
          body: `${hwTitle} (${surah}، آية ${fromAyah}-${toAyah})`,
        };
      }
      if (lang === "am") {
        return {
          title: "አዲስ የቤት ሥራ ተሰጥቷል 📖",
          body: `${hwTitle} (${surah}፣ አንቀጽ ${fromAyah}-${toAyah})`,
        };
      }
      return {
        title: "New Homework Assigned 📖",
        body: `${hwTitle} (${surah}, Ayah ${fromAyah}-${toAyah})`,
      };

    case "homework_submitted": {
      const titleSuffix = hwTitle ? ` (${hwTitle})` : "";
      if (lang === "ar") {
        return {
          title: "تم إرسال تدريب الواجب 🎙️",
          body: `أكمل الطالب ${student} الواجب المنزلي${titleSuffix} وأرسله للمراجعة.`,
        };
      }
      if (lang === "am") {
        return {
          title: "የቤት ሥራ ቀርቧል 🎙️",
          body: `${student} የቤት ሥራውን${titleSuffix} አጠናቆ ለግምገማ ልኳል።`,
        };
      }
      return {
        title: "Homework Practiced at Home 🎙️",
        body: `${student} completed home practice${titleSuffix} for review.`,
      };
    }

    case "homework_reviewed":
      if (lang === "ar") {
        return {
          title: "قام الأستاذ بتقييم الواجب ⭐",
          body: `${student}: ${rating}`,
        };
      }
      if (lang === "am") {
        return {
          title: "ኡስታዝ የቤት ሥራውን ገምግመዋል ⭐",
          body: `${student}፦ ${rating}`,
        };
      }
      return {
        title: "Homework Reviewed by Ustaz ⭐",
        body: `${student}: ${rating}`,
      };

    case "hifz_logged":
      if (lang === "ar") {
        return {
          title: "تحديث الحفظ اليومي 📖",
          body: `تسميع ${student} (${surah}): ${rating}`,
        };
      }
      if (lang === "am") {
        return {
          title: "የዕለት ሒፍዝ ተመዝግቧል 📖",
          body: `የ${student} ንባብ (${surah})፦ ${rating}`,
        };
      }
      return {
        title: "Daily Hifz Logged 📖",
        body: `${student} recited ${surah} (${rating}).`,
      };

    case "attendance_marked":
      if (lang === "ar") {
        return {
          title: "تحديث الحضور اليومي ✓",
          body: `تم تسجيل ${student}: ${status} (${date}).`,
        };
      }
      if (lang === "am") {
        return {
          title: "የዕለት ክትትል ተዘምኗል ✓",
          body: `${student} ${status} ተብሎ ተመዝግቧል (${date})።`,
        };
      }
      return {
        title: "Daily Attendance Update ✓",
        body: `${student} was marked ${status} (${date}).`,
      };

    case "weekly_report":
      if (lang === "ar") {
        return {
          title: "تقرير التقدم الأسبوعي 📊",
          body: `التقرير الأسبوعي للطالب ${student}: ${sabaq} (${rating}).`,
        };
      }
      if (lang === "am") {
        return {
          title: "ሳምንታዊ የቁርኣን እድገት ሪፖርት 📊",
          body: `የ${student} ሳምንታዊ ሪፖርት፦ ${sabaq} (${rating})።`,
        };
      }
      return {
        title: "Weekly Quran Progress Report 📊",
        body: `Weekly report for ${student}: ${sabaq} (${rating}).`,
      };

    case "absence_submitted":
      if (lang === "ar") {
        return {
          title: "طلب إذن غياب جديد 📝",
          body: `قدّم ${parent} طلب عذر غياب للطالب ${student}.`,
        };
      }
      if (lang === "am") {
        return {
          title: "አዲስ የፈቃድ ጥያቄ ቀርቧል 📝",
          body: `${parent} ለ${student} የመቅረት ፈቃድ አቅርበዋል።`,
        };
      }
      return {
        title: "Absence Excuse Request 📝",
        body: `${parent} submitted an excuse for ${student}.`,
      };

    case "absence_approved":
      if (lang === "ar") {
        return {
          title: "تمت الموافقة على عذر الغياب ✅",
          body: `تمت الموافقة على عذر الغياب للطالب ${student}.`,
        };
      }
      if (lang === "am") {
        return {
          title: "የመቅረት ፈቃድ ጸድቋል ✅",
          body: `ለ${student} የቀረበው የመቅረት ፈቃድ ጸድቋል።`,
        };
      }
      return {
        title: "Absence Excuse Approved ✅",
        body: `Absence excuse for ${student} has been approved.`,
      };

    case "absence_declined":
      if (lang === "ar") {
        return {
          title: "تحديث طلب الغياب",
          body: `تم رفض طلب عذر الغياب للطالب ${student}.`,
        };
      }
      if (lang === "am") {
        return {
          title: "የመቅረት ጥያቄ ማሻሻያ",
          body: `ለ${student} የቀረበው የመቅረት ፈቃድ ተቀባይነት አላገኘም።`,
        };
      }
      return {
        title: "Absence Request Update",
        body: `Absence excuse for ${student} was declined.`,
      };

    case "student_enrolled":
      if (lang === "ar") {
        return {
          title: "تم تسجيل طالب جديد 🎓",
          body: `تم تسجيل ${student} في حلقة ${halaqah} وربطه بحسابك.`,
        };
      }
      if (lang === "am") {
        return {
          title: "አዲስ ተማሪ ተመዝግቧል 🎓",
          body: `${student} በ${halaqah} ሐለቃ ተመዝግቦ ከመለያዎ ጋር ተገናኝቷል።`,
        };
      }
      return {
        title: "New Student Enrolled 🎓",
        body: `${student} has been enrolled in ${halaqah} and linked to your account.`,
      };

    case "chat_voice":
      return {
        title: sender,
        body: lang === "ar"
          ? `رسالة صوتية (${duration}ث)`
          : lang === "am"
          ? `የድምጽ መልእክት (${duration}ሴ)`
          : `Voice message (${duration}s)`,
      };

    case "chat_photo":
      return {
        title: sender,
        body: lang === "ar"
          ? "مرفق صورة"
          : lang === "am"
          ? "የፎቶ አባሪ"
          : "Photo attachment",
      };

    case "chat_document":
      return {
        title: sender,
        body: lang === "ar"
          ? `مستند: ${fileName}`
          : lang === "am"
          ? `ሰነድ፦ ${fileName}`
          : `Document: ${fileName}`,
      };

    case "chat_message":
      return {
        title: sender,
        body: msgBody ||
          (lang === "ar"
            ? "لديك رسالة جديدة"
            : lang === "am"
            ? "አዲስ መልእክት ደርሶዎታል"
            : "New message received"),
      };

    case "security_alert":
      if (lang === "ar") {
        return {
          title: "تنبيه أمني عاجل",
          body: `حاول ${actor} الوصول إلى سجل المالية المقيد.`,
        };
      }
      if (lang === "am") {
        return {
          title: "አስቸኳይ የደህንነት ማንቂያ",
          body: `${actor} የተገደበውን የፋይናንስ መዝገብ ለማግኘት ሞክሯል።`,
        };
      }
      return {
        title: "Security Alert",
        body: `${actor} attempted to access restricted financial ledger.`,
      };

    default:
      return { title: fallbackTitle, body: fallbackBody };
  }
}

function stringifyDataMap(
  rawData: Record<string, unknown> | undefined,
  title: string,
  body: string,
  type: string,
): Record<string, string> {
  const result: Record<string, string> = {
    title,
    body,
    type,
  };
  if (rawData && typeof rawData === "object") {
    for (const [k, v] of Object.entries(rawData)) {
      if (v !== undefined && v !== null) {
        result[k] = typeof v === "string" ? v : JSON.stringify(v);
      }
    }
  }
  return result;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ success: false, message: "Method not allowed." }, 405);
  }

  try {
    const saRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (!saRaw || saRaw.trim() === "") {
      return jsonResponse(
        {
          success: false,
          configured: false,
          message:
            "FIREBASE_SERVICE_ACCOUNT_JSON secret is not configured in Supabase Edge Function secrets.",
        },
        500,
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
    }

    const sbHeaders = {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
    };

    // -------------------------------------------------------------------------
    // 1. Authenticate caller: Webhook Secret OR verified active Supabase JWT
    // -------------------------------------------------------------------------
    let authMode: "webhook" | "jwt" | null = null;
    let callerId: string | null = null;
    let callerRole = "";

    const configuredWebhookSecret = (Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "").trim();
    const incomingWebhookSecret = (req.headers.get("x-webhook-secret") ?? "").trim();

    if (
      configuredWebhookSecret.length > 0 &&
      incomingWebhookSecret.length > 0 &&
      timingSafeEqualStrings(configuredWebhookSecret, incomingWebhookSecret)
    ) {
      authMode = "webhook";
    } else {
      const authHeader = req.headers.get("authorization") ?? "";
      const match = authHeader.match(/^Bearer\s+(.+)$/i);
      const jwt = match?.[1]?.trim() ?? "";

      if (!jwt) {
        return jsonResponse(
          { success: false, message: "Unauthorized: missing credentials." },
          401,
        );
      }

      const authRes = await fetch(`${supabaseUrl}/auth/v1/user`, {
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${jwt}`,
        },
      });
      if (!authRes.ok) {
        return jsonResponse(
          { success: false, message: "Unauthorized: invalid or expired token." },
          401,
        );
      }

      const authUser = (await authRes.json()) as { id?: string };
      if (!authUser?.id || !UUID_RE.test(authUser.id)) {
        return jsonResponse(
          { success: false, message: "Unauthorized: user identity unavailable." },
          401,
        );
      }

      const profRes = await fetch(
        `${supabaseUrl}/rest/v1/profiles?select=id,role,is_suspended&id=eq.${encodeURIComponent(
          authUser.id,
        )}`,
        { headers: sbHeaders },
      );
      if (!profRes.ok) {
        throw new Error("Failed to verify caller profile.");
      }

      const profRows = (await profRes.json()) as Array<{
        id: string;
        role?: string;
        is_suspended?: boolean;
      }>;
      const callerProfile = profRows[0];
      if (!callerProfile || callerProfile.is_suspended === true) {
        return jsonResponse(
          { success: false, message: "Forbidden: account suspended or inactive." },
          403,
        );
      }

      authMode = "jwt";
      callerId = callerProfile.id;
      callerRole = String(callerProfile.role ?? "").toLowerCase().trim();
    }

    // -------------------------------------------------------------------------
    // 2. Parse & normalize direct or Supabase Database Webhook payload
    // -------------------------------------------------------------------------
    const rawPayload = (await req.json()) as Record<string, unknown>;
    const isDbWebhookRecord =
      authMode === "webhook" &&
      rawPayload.table === "notifications" &&
      rawPayload.type === "INSERT" &&
      rawPayload.record !== null &&
      typeof rawPayload.record === "object";

    const sourceObj = isDbWebhookRecord
      ? (rawPayload.record as Record<string, unknown>)
      : rawPayload;

    const title = String(sourceObj.title ?? "Kheyrukum Islamic Center").trim();
    const body = String(sourceObj.body ?? "").trim();
    const type = String(sourceObj.type ?? "general").trim() || "general";
    const dataObj =
      sourceObj.data && typeof sourceObj.data === "object"
        ? (sourceObj.data as Record<string, unknown>)
        : undefined;

    if (!body) {
      return jsonResponse(
        { success: false, message: "Notification body is required." },
        400,
      );
    }

    let targetAudience = String(
      sourceObj.target_audience ??
        (isDbWebhookRecord
          ? sourceObj.user_id
            ? ""
            : (dataObj?.target_audience ?? "all")
          : ""),
    )
      .trim()
      .toLowerCase();

    const rawUserIds: unknown[] = isDbWebhookRecord
      ? sourceObj.user_id
        ? [sourceObj.user_id]
        : []
      : Array.isArray(rawPayload.user_ids)
      ? rawPayload.user_ids
      : [];

    const requestedUserIds = Array.from(
      new Set(
        rawUserIds
          .map((u) => String(u ?? "").trim())
          .filter((u) => UUID_RE.test(u)),
      ),
    );

    const excludeUserId =
      authMode === "jwt"
        ? callerId
        : rawPayload.exclude_user_id &&
            UUID_RE.test(String(rawPayload.exclude_user_id).trim())
        ? String(rawPayload.exclude_user_id).trim()
        : null;

    // -------------------------------------------------------------------------
    // 3. Enforce role-based authorization on broadcast vs targeted delivery
    // -------------------------------------------------------------------------
    const isAdminCaller = callerRole === "admin" || callerRole === "superadmin";

    if (targetAudience) {
      if (!["all", "parents", "teachers", "admins"].includes(targetAudience)) {
        return jsonResponse(
          { success: false, message: `Invalid target_audience: ${targetAudience}` },
          400,
        );
      }
      if (authMode === "jwt" && !isAdminCaller) {
        return jsonResponse(
          {
            success: false,
            message:
              "Forbidden: only active administrators may broadcast by target_audience.",
          },
          403,
        );
      }
    } else if (requestedUserIds.length === 0) {
      return jsonResponse(
        {
          success: false,
          message: "Either valid user_ids or an admin target_audience is required.",
        },
        400,
      );
    }

    if (
      authMode === "jwt" &&
      !isAdminCaller &&
      requestedUserIds.length > MAX_NON_ADMIN_RECIPIENTS
    ) {
      return jsonResponse(
        {
          success: false,
          message: `Forbidden: non-admin direct push is limited to ${MAX_NON_ADMIN_RECIPIENTS} recipients.`,
        },
        403,
      );
    }

    // -------------------------------------------------------------------------
    // 4. Resolve eligible recipient user IDs (with full pagination >1000 rows)
    // -------------------------------------------------------------------------
    const recipientIds = new Set<string>(requestedUserIds);

    const resolveAudienceUsers = async (audience: string) => {
      let baseUrl =
        `${supabaseUrl}/rest/v1/profiles?select=id&or=(is_suspended.is.null,is_suspended.eq.false)`;
      if (audience === "admins") {
        baseUrl += "&role=in.(admin,superadmin)";
      } else if (audience === "parents") {
        baseUrl += "&role=eq.parent";
      } else if (audience === "teachers") {
        baseUrl += "&role=eq.teacher";
      }

      let offset = 0;
      while (true) {
        const res = await fetch(baseUrl, {
          headers: {
            ...sbHeaders,
            Range: `${offset}-${offset + PAGE_SIZE - 1}`,
          },
        });
        if (!res.ok) {
          const txt = await res.text();
          throw new Error(`Failed to resolve audience profiles: ${txt}`);
        }
        const rows = (await res.json()) as Array<{ id: string }>;
        for (const r of rows) {
          if (r.id && UUID_RE.test(r.id)) {
            recipientIds.add(r.id);
          }
        }
        if (rows.length < PAGE_SIZE) {
          break;
        }
        offset += PAGE_SIZE;
      }
    };

    if (targetAudience && (targetAudience !== "all" || recipientIds.size === 0)) {
      await resolveAudienceUsers(targetAudience);
    }

    if (excludeUserId) {
      recipientIds.delete(excludeUserId);
    }

    if (recipientIds.size === 0) {
      return jsonResponse({
        success: true,
        sent: 0,
        message: "No eligible recipients found.",
      });
    }

    // -------------------------------------------------------------------------
    // 5. Fetch active FCM tokens + preferred_language via POST RPC (chunked)
    // -------------------------------------------------------------------------
    const idList = Array.from(recipientIds);
    const tokenLangMap = new Map<string, string>();

    for (let i = 0; i < idList.length; i += RPC_BATCH_SIZE) {
      const batch = idList.slice(i, i + RPC_BATCH_SIZE);
      let rpcResp = await fetch(
        `${supabaseUrl}/rest/v1/rpc/get_fcm_tokens_with_lang`,
        {
          method: "POST",
          headers: sbHeaders,
          body: JSON.stringify({ p_user_ids: batch }),
        },
      );
      if (!rpcResp.ok && (rpcResp.status === 404 || rpcResp.status === 400)) {
        const errTxt = await rpcResp.clone().text();
        if (
          errTxt.includes("PGRST202") ||
          errTxt.includes("get_fcm_tokens_with_lang")
        ) {
          rpcResp = await fetch(
            `${supabaseUrl}/rest/v1/rpc/get_fcm_tokens_for_users`,
            {
              method: "POST",
              headers: sbHeaders,
              body: JSON.stringify({ p_user_ids: batch }),
            },
          );
        }
      }
      if (!rpcResp.ok) {
        const txt = await rpcResp.text();
        throw new Error(`Failed to fetch device tokens via RPC: ${txt}`);
      }
      const rows = (await rpcResp.json()) as TokenRow[];
      for (const row of rows) {
        const token = row.device_token?.trim();
        if (token && !token.startsWith("dev_")) {
          tokenLangMap.set(token, normLang(row.preferred_language));
        }
      }
    }

    const uniqueTokens = Array.from(tokenLangMap.keys());
    if (uniqueTokens.length === 0) {
      return jsonResponse({
        success: true,
        sent: 0,
        message: "No active FCM device tokens registered for target users.",
      });
    }

    // -------------------------------------------------------------------------
    // 6. Dispatch via FCM HTTP v1 per recipient language + prune stale tokens
    // -------------------------------------------------------------------------
    const serviceAccount = parseServiceAccount(saRaw);
    const accessToken = await getGoogleAccessToken(serviceAccount);
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
    const { templateKey, templateParams } = extractTemplateMeta(dataObj);

    let sentCount = 0;
    const staleTokens = new Set<string>();
    const errors: string[] = [];

    for (let i = 0; i < uniqueTokens.length; i += FCM_CONCURRENCY) {
      const batch = uniqueTokens.slice(i, i + FCM_CONCURRENCY);
      const results = await Promise.allSettled(
        batch.map(async (token) => {
          const lang = tokenLangMap.get(token) ?? "en";
          const rendered = templateKey
            ? renderLocalizedNotification(
                templateKey,
                templateParams,
                lang,
                title,
                body,
              )
            : { title, body };
          const stringData = stringifyDataMap(
            dataObj,
            rendered.title,
            rendered.body,
            type,
          );
          const messageBody = {
            message: {
              token,
              notification: {
                title: rendered.title,
                body: rendered.body,
              },
              data: stringData,
              android: {
                priority: "HIGH",
                notification: {
                  channel_id: DEFAULT_CHANNEL_ID,
                  icon: DEFAULT_ANDROID_ICON,
                  sound: "default",
                  default_sound: true,
                  default_vibrate_timings: true,
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                  },
                },
              },
            },
          };

          const fcmRes = await fetch(fcmEndpoint, {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify(messageBody),
          });

          if (fcmRes.ok) {
            return { ok: true as const, token };
          }
          const errBody = await fcmRes.text();
          return {
            ok: false as const,
            token,
            status: fcmRes.status,
            errBody,
          };
        }),
      );

      for (const result of results) {
        if (result.status === "fulfilled") {
          const val = result.value;
          if (val.ok) {
            sentCount++;
          } else {
            errors.push(val.errBody.slice(0, 200));
            if (
              val.status === 404 ||
              val.errBody.includes("UNREGISTERED") ||
              val.errBody.includes("INVALID_ARGUMENT") ||
              val.errBody.includes("registration-token-not-registered")
            ) {
              staleTokens.add(val.token);
            }
          }
        } else {
          errors.push(String(result.reason).slice(0, 200));
        }
      }
    }

    const staleList = Array.from(staleTokens);
    for (let i = 0; i < staleList.length; i += FCM_CONCURRENCY) {
      const pruneBatch = staleList.slice(i, i + FCM_CONCURRENCY);
      await Promise.allSettled(
        pruneBatch.map((badToken) =>
          fetch(
            `${supabaseUrl}/rest/v1/user_device_tokens?device_token=eq.${encodeURIComponent(
              badToken,
            )}`,
            {
              method: "DELETE",
              headers: sbHeaders,
            },
          ),
        ),
      );
    }

    return jsonResponse({
      success: true,
      sent: sentCount,
      total_tokens: uniqueTokens.length,
      pruned_tokens: staleList.length,
      errors: errors.slice(0, 5),
    });
  } catch (err) {
    return jsonResponse(
      {
        success: false,
        message: err instanceof Error ? err.message : String(err),
      },
      500,
    );
  }
});
