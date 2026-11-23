import os
import sys
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

def build_full_documentation():
    doc = Document()

    # Configure Margins: 1.0 inch all around
    for section in doc.sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)

    # Color Palette Constants
    COLOR_PRIMARY_HEX = "0D5C46"      # Deep Islamic Emerald
    COLOR_PRIMARY_DARK = "07382B"     # Midnight Pine
    COLOR_GOLD_HEX = "C5A059"         # Desert Gold
    COLOR_SLATE_HEX = "1E293B"        # Charcoal Slate
    COLOR_MUTED_HEX = "64748B"        # Muted Slate Grey
    COLOR_BG_LIGHT = "F8FAFC"         # Light Grey/Ivory
    COLOR_BORDER_HEX = "CBD5E1"       # Light Border Grey

    COLOR_PRIMARY_RGB = RGBColor(13, 92, 70)
    COLOR_GOLD_RGB = RGBColor(197, 160, 89)
    COLOR_SLATE_RGB = RGBColor(30, 41, 59)
    COLOR_MUTED_RGB = RGBColor(100, 116, 139)

    # Helpers for Styling
    def set_cell_background(cell, fill_hex):
        shading = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
        cell._tc.get_or_add_tcPr().append(shading)

    def set_cell_margins(cell, top=130, bottom=130, left=180, right=180):
        tcPr = cell._tc.get_or_add_tcPr()
        tcMar = parse_xml(
            f'<w:tcMar {nsdecls("w")}>'
            f'<w:top w:w="{top}" w:type="dxa"/>'
            f'<w:bottom w:w="{bottom}" w:type="dxa"/>'
            f'<w:left w:w="{left}" w:type="dxa"/>'
            f'<w:right w:w="{right}" w:type="dxa"/>'
            f'</w:tcMar>'
        )
        tcPr.append(tcMar)

    def set_table_borders(table, color=COLOR_BORDER_HEX, sz="4", val="single"):
        tblPr = table._tbl.tblPr
        borders = parse_xml(
            f'<w:tblBorders {nsdecls("w")}>'
            f'<w:top w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
            f'<w:bottom w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
            f'<w:insideH w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
            f'<w:insideV w:val="none"/>'
            f'<w:left w:val="none"/>'
            f'<w:right w:val="none"/>'
            f'</w:tblBorders>'
        )
        tblPr.append(borders)

    def add_h1(title, number=""):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(22)
        p.paragraph_format.space_after = Pt(8)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(f"{number} {title}" if number else title)
        run.font.name = "Arial"
        run.font.size = Pt(17)
        run.font.bold = True
        run.font.color.rgb = COLOR_PRIMARY_RGB
        return p

    def add_h2(title, number=""):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(15)
        p.paragraph_format.space_after = Pt(5)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(f"{number} {title}" if number else title)
        run.font.name = "Arial"
        run.font.size = Pt(13)
        run.font.bold = True
        run.font.color.rgb = COLOR_PRIMARY_RGB
        return p

    def add_h3(title):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(11)
        p.paragraph_format.space_after = Pt(3)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(title)
        run.font.name = "Arial"
        run.font.size = Pt(11)
        run.font.bold = True
        run.font.color.rgb = COLOR_GOLD_RGB
        return p

    def add_body(text, bold_prefix="", italic=False):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(6)
        p.paragraph_format.line_spacing = 1.15
        if bold_prefix:
            r_bold = p.add_run(bold_prefix + " ")
            r_bold.font.name = "Calibri"
            r_bold.font.size = Pt(10.5)
            r_bold.font.bold = True
            r_bold.font.color.rgb = COLOR_SLATE_RGB
        r = p.add_run(text)
        r.font.name = "Calibri"
        r.font.size = Pt(10.5)
        r.font.italic = italic
        r.font.color.rgb = COLOR_SLATE_RGB
        return p

    def add_bullet(text, bold_prefix=""):
        p = doc.add_paragraph(style='List Bullet')
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(3)
        p.paragraph_format.line_spacing = 1.12
        if bold_prefix:
            r_bold = p.add_run(bold_prefix + " ")
            r_bold.font.name = "Calibri"
            r_bold.font.size = Pt(10.5)
            r_bold.font.bold = True
            r_bold.font.color.rgb = COLOR_SLATE_RGB
        r = p.add_run(text)
        r.font.name = "Calibri"
        r.font.size = Pt(10.5)
        r.font.color.rgb = COLOR_SLATE_RGB
        return p

    def add_callout(text, title="KEY ARCHITECTURAL HIGHLIGHT"):
        tbl = doc.add_table(rows=1, cols=1)
        tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
        tbl.autofit = False
        tbl.columns[0].width = Inches(6.5)
        cell = tbl.cell(0, 0)
        set_cell_background(cell, COLOR_BG_LIGHT)
        set_cell_margins(cell, top=130, bottom=130, left=180, right=150)
        
        tcPr = cell._tc.get_or_add_tcPr()
        borders = parse_xml(
            f'<w:tcBorders {nsdecls("w")}>'
            f'<w:left w:val="single" w:sz="24" w:color="{COLOR_PRIMARY_HEX}"/>'
            f'<w:top w:val="none"/>'
            f'<w:bottom w:val="none"/>'
            f'<w:right w:val="none"/>'
            f'</w:tcBorders>'
        )
        tcPr.append(borders)

        cp = cell.paragraphs[0]
        cp.paragraph_format.space_before = Pt(0)
        cp.paragraph_format.space_after = Pt(4)
        r_title = cp.add_run(f"[{title}] ")
        r_title.font.name = "Arial"
        r_title.font.size = Pt(9.5)
        r_title.font.bold = True
        r_title.font.color.rgb = COLOR_PRIMARY_RGB

        r_text = cp.add_run(text)
        r_text.font.name = "Calibri"
        r_text.font.size = Pt(10)
        r_text.font.italic = True
        r_text.font.color.rgb = COLOR_SLATE_RGB

        doc.add_paragraph().paragraph_format.space_after = Pt(4)

    def add_styled_table(headers, data, col_widths=None):
        tbl = doc.add_table(rows=len(data) + 1, cols=len(headers))
        tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
        tbl.autofit = False
        set_table_borders(tbl)

        hdr_cells = tbl.rows[0].cells
        for i, header_text in enumerate(headers):
            cell = hdr_cells[i]
            if col_widths and i < len(col_widths):
                cell.width = col_widths[i]
            set_cell_background(cell, COLOR_PRIMARY_HEX)
            set_cell_margins(cell, top=120, bottom=120, left=130, right=130)
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            p = cell.paragraphs[0]
            p.paragraph_format.space_before = Pt(0)
            p.paragraph_format.space_after = Pt(0)
            r = p.add_run(header_text)
            r.font.name = "Arial"
            r.font.size = Pt(9.5)
            r.font.bold = True
            r.font.color.rgb = RGBColor(255, 255, 255)

        for r_idx, row_data in enumerate(data):
            row_cells = tbl.rows[r_idx + 1].cells
            row_bg = COLOR_BG_LIGHT if r_idx % 2 == 1 else "FFFFFF"
            for c_idx, val in enumerate(row_data):
                cell = row_cells[c_idx]
                if col_widths and c_idx < len(col_widths):
                    cell.width = col_widths[c_idx]
                set_cell_background(cell, row_bg)
                set_cell_margins(cell, top=80, bottom=80, left=130, right=130)
                cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
                p = cell.paragraphs[0]
                p.paragraph_format.space_before = Pt(0)
                p.paragraph_format.space_after = Pt(0)
                r = p.add_run(str(val))
                r.font.name = "Calibri"
                r.font.size = Pt(9.5)
                r.font.color.rgb = COLOR_SLATE_RGB

        doc.add_paragraph().paragraph_format.space_after = Pt(6)
        return tbl

    print("Building Document Content...")

    # =========================================================================
    # DOCUMENT COVER BLOCK
    # =========================================================================
    p_title = doc.add_paragraph()
    p_title.paragraph_format.space_before = Pt(36)
    p_title.paragraph_format.space_after = Pt(4)
    r1 = p_title.add_run("KHEYRUKUM ISLAMIC CENTER")
    r1.font.name = "Arial"
    r1.font.size = Pt(28)
    r1.font.bold = True
    r1.font.color.rgb = COLOR_PRIMARY_RGB

    p_sub = doc.add_paragraph()
    p_sub.paragraph_format.space_before = Pt(0)
    p_sub.paragraph_format.space_after = Pt(14)
    r2 = p_sub.add_run("Mobile Portal Architecture & Functional Specification Manual")
    r2.font.name = "Arial"
    r2.font.size = Pt(16)
    r2.font.bold = True
    r2.font.color.rgb = COLOR_GOLD_RGB

    p_meta = doc.add_paragraph()
    p_meta.paragraph_format.space_before = Pt(0)
    p_meta.paragraph_format.space_after = Pt(20)
    r3 = p_meta.add_run(
        "A Comprehensive Technical & Operational Guide on What the App Does and How It Does It\n"
        "Platform: Android Native (Flutter 3.50+ & Supabase Enterprise Cloud)\n"
        "Target Audience: Center Directors, Executive Leadership, IT Engineers & Academic Staff\n"
        "Release Version: 2.0 (Flagship Release) | Published: November 2026"
    )
    r3.font.name = "Calibri"
    r3.font.size = Pt(10.5)
    r3.font.italic = True
    r3.font.color.rgb = COLOR_MUTED_RGB

    p_div = doc.add_paragraph()
    p_div.paragraph_format.space_after = Pt(16)
    p_div.add_run("―" * 58).font.color.rgb = COLOR_GOLD_RGB

    # =========================================================================
    # SECTION 1: EXECUTIVE OVERVIEW & PLATFORM PHILOSOPHY
    # =========================================================================
    add_h1("1. Executive Overview & Platform Philosophy")
    add_body(
        "The Kheyrukum Islamic Center Mobile Application is a purpose-built, flagship educational management "
        "and Quran memorization platform created to digitize and elevate the operations of Islamic academies. "
        "Historically, Quranic madrasas and Islamic learning centers have struggled with fragmented operational tools: "
        "paper logbooks for Hifz memorization, unmonitored messaging groups for parent-teacher communication, manual receipt "
        "booklets for fee collection, and physical paper circulars that rarely reached parents on time."
    )
    add_body(
        "Kheyrukum replaces this fragmented approach with a cohesive, beautifully designed mobile application that unites "
        "the five critical pillars of modern school administration: Academic Study Circles (Halaqahs), Daily Quran Memorization (Hifz), "
        "Home Recitation Audio Review, Financial Governance (Invoices & Receipts), and School-Wide Broadcast Communications."
    )

    add_callout(
        "The platform is built on an absolute principle of Zero Operational Leakage: every academic event (recitation grade, "
        "attendance mark, homework audio submission, bank slip upload) is cryptographically signed, timestamped, stored with "
        "ACID guarantees in PostgreSQL, and pushed via WebSockets to authenticated parent devices in real time.",
        "CORE ARCHITECTURAL PHILOSOPHY"
    )

    core_pillars = [
        ["Pillar 1: Quran Memorization Mastery", "Real-time logging of daily Surah/Ayah recitations, Tajweed mistake tallies, and qualitative ratings."],
        ["Pillar 2: High-Fidelity Recitation Studio", "In-app audio studio allowing students to record recitations at home and teachers to listen, grade, and coach."],
        ["Pillar 3: Strict Financial Governance", "Segregated tuition invoicing managed exclusively by Superadmins, with bank slip uploads and automated reminders."],
        ["Pillar 4: Trilingual Cultural Inclusivity", "Seamless instant switching between English, Arabic (with RTL & Naskh styling), and Amharic (Ge'ez script)."],
        ["Pillar 5: Closed-App Notification Sync", "Firebase Cloud Messaging backed by persistent database synchronization, ensuring no alert is ever lost."]
    ]
    add_styled_table(["Institutional Pillar", "Operational Execution"], core_pillars, [Inches(2.5), Inches(4.0)])

    # =========================================================================
    # SECTION 2: USER PERSONAS & ROLE HIERARCHY
    # =========================================================================
    add_h1("2. User Personas & Role-Based Access Control (RBAC)")
    add_body(
        "Access control in Kheyrukum is governed by a strict 4-tier role hierarchy. Unlike traditional systems that treat "
        "'Admin' as a monolithic superuser, Kheyrukum enforces a critical organizational separation between operational "
        "Center Administrators and the Executive Superadmin."
    )

    add_h2("2.1 Persona Definitions")
    add_bullet(
        "The highest institutional authority (Center Director / Board). Possesses full administrative rights across all modules. "
        "Exclusively possesses access to view the school financial ledger, issue monthly fee invoices, verify and approve bank payment slips, "
        "and promote or demote user accounts between roles.",
        "1. Superadmin (Center Director):"
    )
    add_bullet(
        "Operational day-to-day manager (Academic Coordinator / Registrar). Responsible for student enrollment, halaqah assignments, "
        "teacher schedules, attendance audits, broadcast notices, and parent onboarding codes. "
        "STRICT SECURITY RESTRICTION: Administrators have ZERO access to payment records, fee invoices, or financial ledgers. "
        "The payment tab and invoicing endpoints are blocked both visually and at the database RLS layer.",
        "2. Admin (Center Administrator):"
    )
    add_bullet(
        "Quran instructors (Ustazs). Responsible for managing assigned memorization circles, marking daily attendance, "
        "recording daily Hifz recitations and Tajweed errors, issuing Quran homework, listening to student audio submissions, "
        "and engaging in direct messaging with parents of assigned students.",
        "3. Teacher (Ustaz):"
    )
    add_bullet(
        "Mothers and fathers of enrolled students. Able to switch between multiple enrolled children seamlessly; view real-time daily "
        "attendance and Hifz marks; record homework recitations using the in-app audio studio; view tuition fee invoices; submit bank deposit slips; "
        "submit advance absence requests; and receive center broadcast notices.",
        "4. Parent (Guardian):"
    )

    add_h2("2.2 Deep Security Matrix (Who Can Do What)")
    perm_table_data = [
        ["Enroll New Student (Age & Avatar)", "Full Access", "Full Access", "View Assigned", "View Own Children"],
        ["Create & Schedule Halaqahs", "Full Access", "Full Access", "View Assigned", "View Enrolled"],
        ["Assign Ustaz to Halaqah", "Full Access", "Full Access", "No Access", "No Access"],
        ["Log Daily Recitation (Surah/Ayah)", "Full Access", "Full Access", "Assigned Circles", "Read-Only (Own)"],
        ["Mark Student Attendance", "Full Access", "Full Access", "Assigned Circles", "Read-Only (Own)"],
        ["Issue Quran Homework", "Full Access", "Full Access", "Assigned Circles", "No Access"],
        ["Record Audio Recitation", "No Access", "No Access", "No Access", "Full Access (Own)"],
        ["Listen & Grade Recitations", "Full Access", "Full Access", "Assigned Circles", "View Feedback"],
        ["Broadcast School Circulars", "Full Access", "Full Access", "Read-Only", "Read-Only"],
        ["Generate Onboarding Codes", "Full Access", "Full Access", "No Access", "No Access"],
        ["Promote / Demote User Roles", "Full Access", "BLOCKED", "BLOCKED", "BLOCKED"],
        ["View Center Financial Ledger", "Full Access", "BLOCKED (RLS)", "BLOCKED", "View Own Invoices"],
        ["Issue Monthly Fee Invoices", "Full Access", "BLOCKED (RLS)", "BLOCKED", "BLOCKED"],
        ["Upload Bank Deposit Receipt", "BLOCKED", "BLOCKED", "BLOCKED", "Full Access (Own)"],
        ["Approve / Verify Payment Slip", "Full Access", "BLOCKED (RLS)", "BLOCKED", "BLOCKED"],
        ["Review Student Absence Request", "Full Access", "Full Access", "Assigned Circles", "Submit Own"]
    ]
    add_styled_table(["Capability / Action", "Superadmin", "Admin", "Teacher", "Parent"], perm_table_data, [Inches(2.5), Inches(1.0), Inches(1.0), Inches(1.0), Inches(1.0)])

    # =========================================================================
    # SECTION 3: SYSTEM MODULES (WHAT IT DOES & HOW IT DOES IT)
    # =========================================================================
    add_h1("3. System Modules — Deep Functional & Technical Specifications")

    # Module 1
    add_h2("3.1 Authentication, Safe Onboarding & Cryptographic Invite Codes", "Module 1:")
    add_body(
        "Kheyrukum enforces a closed-loop onboarding architecture. Public users cannot arbitrarily sign up as teachers "
        "or parents without an authorized invitation code generated by center leadership."
    )
    add_bullet(
        "Users can log in using their registered email and password. New teachers and parents can redeem single-use invitation "
        "tokens during onboarding. The application securely maintains the authenticated session across app restarts, supports "
        "password reset workflows, and displays role-specific UI immediately upon authentication.",
        "What It Does:"
    )
    add_bullet(
        "Built on Supabase Auth (JWT). When an administrator generates an invite code in InviteCodesBottomSheet, a record is created "
        "in public.invitation_codes with a unique alphanumeric string (e.g., USTAZ-8492), target role ('teacher' or 'parent'), "
        "and expiration timestamp. When the new user signs up in AuthScreen, the client invokes the PostgreSQL security-definer function "
        "consume_invitation_code(p_code, p_user_id). The function validates code unicity, checks expiration, marks is_used = TRUE, "
        "and sets the newly created profile role in public.profiles to the target role in an atomic database transaction.",
        "How It Does It:"
    )

    # Module 2
    add_h2("3.2 Dynamic Adaptive Dashboard & Meniscus Floating Navigation", "Module 2:")
    add_body(
        "The central dashboard acts as an operational command center tailored specifically to the authenticated persona."
    )
    add_bullet(
        "Provides real-time KPI overview cards, active circular banners, quick-action shortcuts (Add Student, Issue Invite, "
        "Post Notice, View Circles), student selector tabs for parents, and a custom curved navigation bar.",
        "What It Does:"
    )
    add_bullet(
        "Orchestrated in DashboardScreen and MeniscusNavBar. The custom Meniscus floating bar renders an SVG-style parabolic notch "
        "that slides dynamically to frame the active tab with spring-damper animations (MeniscusPainter). For administrators, "
        "an Academy Overview glass card displays live counts of enrolled students, active halaqahs, and Ustazs. "
        "For parents, a child selector ribbon allows switching between multiple siblings with one tap, updating all tab streams "
        "instantly via ValueNotifiers. The top bar features ProAvatar with gold director rings for superadmins, "
        "a live role badge, notification bell with unread counters, and portal settings trigger.",
        "How It Does It:"
    )

    # Module 3
    add_h2("3.3 Academy & Study Circle (Halaqah) Operations", "Module 3:")
    add_bullet(
        "Organizes the academy's student body into structured Quranic study circles based on memorization stage, age, and schedule.",
        "What It Does:"
    )
    add_bullet(
        "Managed via HalaqahService and HalaqahManagementSheet. Circle records in public.halaqahs maintain circle_name, "
        "schedule (e.g., 'Mon-Thu 4:00 PM - 6:00 PM'), room, level (Beginner, Intermediate, Advanced, Khatm), max_capacity, and teacher_id. "
        "Administrators assign teachers via the RPC admin_assign_teacher_halaqah(p_teacher_id, p_halaqah_id), which validates "
        "teacher qualifications and updates the teacher-circle relationship atomically. Enrolled students are mapped to circles "
        "via foreign key on public.students.halaqah_id.",
        "How It Does It:"
    )

    # Module 4
    add_h2("3.4 Student Lifecycle & Profile Management", "Module 4:")
    add_bullet(
        "Allows center staff to enroll students with mandatory age tracking and optional profile photos, manage circle placement, "
        "and establish parent-child links.",
        "What It Does:"
    )
    add_bullet(
        "Managed via AddStudentDialog, StudentService, and StorageService. Enrolling a student requires: full name, mandatory age "
        "(validated integer between 1 and 99), study circle selection, optional avatar photo, and parent email. "
        "When an avatar is picked, StorageService uploads the image directly to the Supabase Storage avatars bucket under "
        "avatars/students/{uuid}.jpg with public read permissions and authenticated upload policies. "
        "The parent is linked via public.parent_students, enabling parents to see their children immediately upon login.",
        "How It Does It:"
    )

    # Module 5
    add_h2("3.5 Daily Hifz Memorization & Attendance Engine", "Module 5:")
    add_bullet(
        "Empowers Quran teachers to record daily student attendance and Quran recitation evaluations, providing parents with "
        "complete daily visibility into their child's Quranic journey.",
        "What It Does:"
    )
    add_bullet(
        "Executed in StudentsTab. For each student, the Ustaz marks attendance (Present, Absent, Excused, Late). "
        "For the memorization recitation, the teacher records: 1) Surah name, 2) Starting Ayah, 3) Ending Ayah, 4) Number of Tajweed/hesitation mistakes, "
        "5) Qualitative grade (Mumtaz / Excellent, Jayyid Jiddan / Very Good, Jayyid / Good, Maqbool / Acceptable), and 6) Instructor notes. "
        "Submitting writes to public.hifz_records. Supabase Realtime pushes changes immediately to the parent's dashboard, "
        "where a weekly progress card displays recitation history and performance trends.",
        "How It Does It:"
    )

    # Module 6
    add_h2("3.6 Quran Homework & In-App Voice Recitation Studio", "Module 6:")
    add_bullet(
        "Bridges the academy and the home. Teachers assign specific Quranic passages for home memorization; students record their recitations "
        "using an in-app voice recording studio; teachers listen to the audio files and provide grades and feedback.",
        "What It Does:"
    )
    add_bullet(
        "Implemented across HomeworkService, HomeworkTab, and the Flutter 'record' and 'audioplayers' plugins. "
        "Teachers define homework in public.homework_assignments with Surah/Ayah range, instructions, and due date. "
        "On the parent's app, an in-app Recording Studio widget captures audio via the device microphone, encoding it into compressed AAC/M4A format. "
        "Upon submission, the audio file is uploaded to the Supabase Storage homework_audio bucket and recorded in public.homework_submissions. "
        "Teachers listen to the recitation via a custom audio player with interactive scrubber, assign a grade, and leave coaching comments.",
        "How It Does It:"
    )

    # Module 7
    add_h2("3.7 Tuition, Invoicing & Strict Financial Governance", "Module 7:")
    add_bullet(
        "Provides an end-to-end tuition billing system. Superadmins issue monthly invoices with explicit fee start dates; "
        "parents view outstanding balances and upload bank deposit slips; superadmins review and approve receipts; automated reminders "
        "notify parents on recurring 30-day cycles.",
        "What It Does:"
    )
    add_bullet(
        "Managed via PaymentService and PaymentsScreen. Standard admins are physically blocked at the database level via PostgreSQL RLS policies "
        "(is_superadmin() check). Superadmins create invoices in public.monthly_payments specifying student_id, parent_id, amount, "
        "fee_start_date, and due_date. Parents view unpaid invoices, select 'Upload Bank Slip / Receipt', pick an image, which is uploaded "
        "to Supabase Storage payment_receipts bucket, updating status to 'pending_verification'. The Superadmin reviews the receipt image "
        "and taps 'Verify & Mark Paid'. The checkAndSendMonthlyFeeReminders() algorithm calculates 30-day billing intervals from fee_start_date "
        "and writes reminder notifications into public.notifications, dispatching push notifications to parents.",
        "How It Does It:"
    )

    # Module 8
    add_h2("3.8 Absence Requests & Automated Excusal Workflow", "Module 8:")
    add_bullet(
        "Allows parents to submit advance notices of upcoming absences (illness, family travel) directly through the app, "
        "eliminating informal WhatsApp messages and unexcused absences.",
        "What It Does:"
    )
    add_bullet(
        "Managed via AbsenceService. Parents select dates and enter reasons. Submissions are stored in public.absence_requests with status 'pending'. "
        "Teachers and Administrators review pending requests in their portal and can approve or reject with one tap. "
        "When approved, the system automatically registers the student as 'Excused' in the daily attendance ledger for the specified date range, "
        "and dispatches a confirmation push notification back to the parent.",
        "How It Does It:"
    )

    # Module 9
    add_h2("3.9 School Circulars & Notice Broadcasting", "Module 9:")
    add_bullet(
        "Enables center leadership to broadcast important announcements, emergency alerts, holiday closures, and event flyers "
        "to the school community.",
        "What It Does:"
    )
    add_bullet(
        "Managed by AnnouncementService, AnnouncementsSheet, and PostAnnouncementDialog. Circulars in public.announcements include "
        "title, content, priority ('normal' vs 'urgent'), target audience ('all', 'teachers', 'parents'), flyer image URL, and expiration date. "
        "Urgent notices render as a gold-bordered dismissible banner at the top of the home screen. Read states are tracked per user "
        "in public.announcement_reads, ensuring unread badges accurately reflect real user consumption across multiple devices.",
        "How It Does It:"
    )

    # Module 10
    add_h2("3.10 Real-Time Chat & Voice Messaging", "Module 10:")
    add_bullet(
        "Provides direct communication channels between parents and their children's teachers, as well as circle group discussions, "
        "featuring instant text messaging and voice audio notes.",
        "What It Does:"
    )
    add_bullet(
        "Powered by MessagingService, MessagesTab, and ChatScreen. Conversations are structured in public.conversations and "
        "public.conversation_participants. Messages are transmitted over Supabase Realtime WebSockets and stored in public.messages. "
        "Users can send text messages or hold-to-record voice notes. Voice notes are uploaded to the voice_messages storage bucket "
        "and rendered as an interactive audio bubble with play/pause and progress scrubbing.",
        "How It Does It:"
    )

    # Module 11
    add_h2("3.11 Trilingual Localization Engine (English, Arabic RTL, Amharic)", "Module 11:")
    add_bullet(
        "Enables instant toggling between English, Arabic, and Amharic across the entire app, providing authentic cultural and linguistic "
        "accessibility for diverse school communities.",
        "What It Does:"
    )
    add_bullet(
        "Orchestrated by LocaleNotifier and AppLocalizations. Language preference is persisted locally via SharedPreferences. "
        "When Arabic ('ar') is activated, the application automatically inverts layout directionality to Right-to-Left (RTL) "
        "and applies elegant Arabic Naskh typography. For Amharic ('am'), the engine utilizes authentic Ge'ez script typography. "
        "Custom FallbackMaterialLocalizationsDelegate and FallbackCupertinoLocalizationsDelegate prevent Flutter framework crashes "
        "on Amharic locales while delivering custom translations for every screen, button, and alert.",
        "How It Does It:"
    )

    # Module 12
    add_h2("3.12 Push Notifications & Closed-App Database Sync", "Module 12:")
    add_bullet(
        "Guarantees that school alerts, circulars, and fee reminders are delivered to user devices even when the app is completely closed "
        "or terminated by the Android operating system.",
        "What It Does:"
    )
    add_bullet(
        "Utilizes Firebase Cloud Messaging (FCM), flutter_local_notifications, and a persistent database logging table (public.notifications). "
        "Device registration tokens are synchronized to public.user_device_tokens. Whenever an announcement or reminder is triggered, "
        "an entry is committed to public.notifications. When the app boots, syncUnreadDatabaseNotifications() queries unread rows "
        "and displays local heads-up banners, ensuring no notification is lost if the device was offline or the app was closed.",
        "How It Does It:"
    )

    # Module 13
    add_h2("3.13 Superadmin User Promotion & Access Governance", "Module 13:")
    add_bullet(
        "Allows Superadmins to promote, demote, or adjust user roles (Superadmin, Admin, Teacher, Parent) directly from the mobile UI.",
        "What It Does:"
    )
    add_bullet(
        "Implemented in UserManagementScreen with the PostgreSQL security-definer stored procedure admin_set_user_role(p_user_id, p_new_role). "
        "The procedure verifies that the caller is authenticated as a Superadmin (is_superadmin() == true). "
        "It includes hardcoded protection preventing demotion or suspension of the primary center executive (admin@kheyrukum.com). "
        "Superadmins can promote trustworthy teachers to administrators or assign co-directors seamlessly.",
        "How It Does It:"
    )

    # Module 14
    add_h2("3.14 Design System & Islamic Geometric Theme Engine", "Module 14:")
    add_bullet(
        "Delivers a distinguished, executive visual identity honoring traditional Islamic aesthetics with contemporary mobile UX standards.",
        "What It Does:"
    )
    add_bullet(
        "Constructed in AppTheme, AppColors, and ProUIkit. Supports two primary modes: 'Warm Sanctuary' (Daylight Ivory background #FBF9F4, "
        "Deep Emerald #0D5C46, and Desert Gold #C5A059) and 'Emerald Night' (Midnight Pine #051F18 and Golden Amber #D4AF37). "
        "Custom canvas painters (IslamicPatternPainter) render Khatam eight-point geometric star lattices across hero cards. "
        "Components feature frosted-glass blur effects, golden accent rings, and tactile haptic feedback.",
        "How It Does It:"
    )

    # =========================================================================
    # SECTION 4: DATABASE ARCHITECTURE & DATA DICTIONARY
    # =========================================================================
    add_h1("4. Database Architecture & Data Dictionary")
    add_body(
        "The backend is powered by PostgreSQL 15 on Supabase. Below is the comprehensive data dictionary of all 16 core "
        "relational tables and their security constraints."
    )

    db_headers = ["Table Name", "Primary Purpose", "Key Columns", "Row-Level Security (RLS) Policy"]
    db_data = [
        ["profiles", "User identities & system roles", "id, email, full_name, role, avatar_url, is_suspended", "Self-read; Superadmin full write; Admins read staff/parents"],
        ["students", "Enrolled students directory", "id, full_name, age, halaqah_id, avatar_url, enrolled_at", "Admins/Superadmins full access; Teachers read assigned; Parents read own"],
        ["parent_students", "Parent-child relationship join", "parent_id, student_id, relationship_type", "Admins/Superadmins manage; Parents view own links"],
        ["halaqahs", "Study circles / Quran classes", "id, circle_name, schedule, room, level, teacher_id", "Admins/Superadmins manage; Teachers view assigned; Parents view enrolled"],
        ["hifz_records", "Daily recitation & attendance", "id, student_id, halaqah_id, surah, ayah_range, grade, mistakes", "Teachers log for assigned circles; Parents read own children's records"],
        ["homework_assignments", "Quran homework tasks", "id, title, halaqah_id, surah_from, surah_to, due_date", "Teachers/Admins create for assigned circles; Parents/Students read"],
        ["homework_submissions", "Audio recitation submissions", "id, assignment_id, student_id, audio_url, status, feedback", "Parents create/upload for own children; Teachers review & grade"],
        ["monthly_payments", "Tuition invoices & fee ledger", "id, student_id, parent_id, amount, fee_start_date, status, receipt_url", "Superadmin full access; Parents view/pay own; ADMIN BLOCKED"],
        ["notifications", "Persistent notification inbox", "id, user_id, title, body, type, is_read, metadata, created_at", "Users read and mark own notifications as read; System inserts"],
        ["announcements", "School circulars & notices", "id, title, content, priority, target_audience, image_url, expires_at", "Admins/Superadmins create; All authenticated users read target rows"],
        ["announcement_reads", "Per-user circular read tracking", "announcement_id, user_id, read_at", "Users insert/read own tracking records"],
        ["conversations", "Chat threads (1-to-1 & Circle)", "id, title, type (direct/halaqah), halaqah_id, created_at", "Participants read and write; Admins view operational channels"],
        ["conversation_participants", "Chat enrollment mapping", "conversation_id, user_id, last_read_at", "Users view own enrolled conversations; Admins manage"],
        ["messages", "Instant messages & voice memos", "id, conversation_id, sender_id, content, audio_url, created_at", "Enrolled participants read and insert messages in their chats"],
        ["invitation_codes", "Secure onboarding invite tokens", "id, code, target_role, is_used, used_by, expires_at", "Admins/Superadmins create & view; Public function consumes atomically"],
        ["user_device_tokens", "FCM push notification tokens", "user_id, token, device_type, updated_at", "Users upsert own device tokens; System sends pushes"]
    ]
    add_styled_table(db_headers, db_data, [Inches(1.5), Inches(1.8), Inches(1.7), Inches(1.5)])

    add_h2("4.1 Stored Procedures & Database Functions (RPCs)")
    add_bullet(
        "admin_set_user_role(p_user_id UUID, p_new_role user_role): SECURITY DEFINER function permitting only active Superadmins "
        "to promote or demote user accounts, strictly protecting admin@kheyrukum.com against demotion.",
        "1. Role Elevation:"
    )
    add_bullet(
        "consume_invitation_code(p_code TEXT, p_user_id UUID): Atomically validates token unicity, expiration date, and unused status, "
        "updates the caller profile to the designated role, and marks the token spent.",
        "2. Invite Token Consumption:"
    )
    add_bullet(
        "admin_assign_teacher_halaqah(p_teacher_id UUID, p_halaqah_id UUID): Validates teacher credentials, sets the circle instructor, "
        "and handles schedule collision checks.",
        "3. Circle Assignment:"
    )
    add_bullet(
        "is_superadmin() & is_admin(): Ultra-fast STABLE helper functions evaluated inside RLS expressions to eliminate recursive query overhead.",
        "4. RLS Helper Predicates:"
    )

    # =========================================================================
    # SECTION 5: SECURITY, PRIVACY & COMPLIANCE
    # =========================================================================
    add_h1("5. Security, Privacy & Data Isolation")
    add_body(
        "The platform architecture treats student safety, parental privacy, and financial confidentiality as foundational imperatives."
    )
    add_bullet(
        "PostgreSQL Row Level Security guarantees that standard center administrators are physically incapable of reading "
        "monthly_payments rows, even if they attempt direct REST API calls. Payment slips and invoices are restricted exclusively "
        "to Superadmins and the biological parent associated with the invoice.",
        "Financial Isolation:"
    )
    add_bullet(
        "Student records, daily recitation marks, Tajweed notes, and audio recitations are accessible solely to the student's assigned "
        "Ustaz, administrators, and the verified parent. Cross-family data leakage is prevented via foreign-key RLS joins on parent_students.",
        "Student Privacy:"
    )
    add_bullet(
        "Student recitation recordings and teacher voice memos are stored in private Supabase Storage buckets (homework_audio, voice_messages). "
        "Access requires authenticated session tokens, preventing unauthorized scraping or indexing.",
        "Audio Privacy:"
    )

    # =========================================================================
    # SECTION 6: CODEBASE ARCHITECTURE & ENGINEERING STANDARDS
    # =========================================================================
    add_h1("6. Codebase Architecture & Engineering Standards")
    add_body(
        "The project follows Clean Service-Oriented Architecture (SOA), decoupling UI view widgets from backend services and domain models."
    )
    add_bullet(
        "lib/core/models/ contains immutable domain models (Student, Payment, Homework, Halaqah, Announcement, ChatMessage, AbsenceRequest) "
        "equipped with robust JSON serialization and defensive null-safety parsing.",
        "Data Models:"
    )
    add_bullet(
        "lib/core/services/ contains singleton service orchestrators (StudentService, PaymentService, HomeworkService, MessagingService, "
        "PushNotificationService, StorageService, AuthSessionService) managing cloud transactions and local offline caching.",
        "Service Layer:"
    )
    add_bullet(
        "lib/screens/ contains clean screen workflows segregated into auth/, dashboard/, admin/, announcements/, messages/, and payments/.",
        "Presentation Layer:"
    )
    add_bullet(
        "lib/widgets/ houses reusable UI building blocks including ProAvatar, GlowingBead, MeniscusNavBar, and IslamicPatternPainter.",
        "UI Component Kit:"
    )
    add_bullet(
        "Automated continuous integration pipeline via GitHub Actions compiles release APKs using Ubuntu runners, Temurin Java 21, "
        "Flutter stable channel, Android compileSdk 36, targetSdk 35, and pinned NDK 27.3.",
        "Build & Release Pipeline:"
    )

    # =========================================================================
    # SECTION 7: SUMMARY & CONCLUSION
    # =========================================================================
    add_h1("7. Conclusion & Institutional Impact")
    add_body(
        "Kheyrukum Islamic Center Mobile Application represents a complete, pro-grade digital transformation for Islamic education. "
        "By synthesizing daily Quran memorization monitoring, audio homework submissions, automated tuition invoicing, "
        "trilingual accessibility (English, Arabic, Amharic), and impenetrable role-based security, the platform provides "
        "the academy with a durable, flagship mobile asset that elevates parent trust and institutional excellence."
    )

    # Save to workspace root
    output_path = "c:\\Users\\Ahmed\\Desktop\\kheyrukummobileapp\\Kheyrukum_Mobile_App_Complete_System_Documentation.docx"
    doc.save(output_path)
    print(f"Document successfully created at: {output_path}")

    # Copy to artifact directory
    artifact_dir = "C:\\Users\\Ahmed\\.gemini\\antigravity\\brain\\cd6e157d-8901-4434-8eed-18949b36cbf4"
    if os.path.exists(artifact_dir):
        artifact_path = os.path.join(artifact_dir, "Kheyrukum_Mobile_App_Complete_System_Documentation.docx")
        doc.save(artifact_path)
        print(f"Artifact copy saved at: {artifact_path}")

if __name__ == "__main__":
    build_full_documentation()
