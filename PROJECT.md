# Project: Kheyrukum Mobile App - Comprehensive Bug Fixes & Modernization

## Architecture
- **Framework**: Flutter (Dart) mobile application targeting Android and iOS.
- **Backend**: Supabase (PostgreSQL 15+, PostgREST, Gotrue Auth, Supabase Storage).
- **Client Architecture**: Service-oriented repository layer (`lib/core/services/`), ChangeNotifier state management, centralized theme (`lib/core/theme/`), and modular UI dashboard tabs (`lib/screens/`).
- **Data Flow**:
  - Offline-first caching via `LocalStorageService` (SharedPreferences) synchronizing bidirectionally with remote Supabase tables.
  - Cloud Storage: Direct multi-part file uploads to authenticated Supabase Storage buckets, saving public/signed URLs in PostgreSQL relational tables.
  - UI Layer: Responsive widgets listening to reactive services with comprehensive loading indicators and sanitized error banners.

---

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Announcements Schema Fix | Add `attachment_name` & `attachment_url` to `announcements` table, reload schema cache (`PGRST204` fix) | M1 | Survey / Request |
| 2 | Student Persistence on Reinstall | Refactor `StudentService` & `AddStudentDialog` to write directly to Supabase `students` table, fix parent UUID linking, add RLS policies, use local cache only for offline sync | M1 | Survey / Request |
| 3 | Halaqah (Circle) Creation Flow | Fix `halaqahs` table RLS policies, payload schema (`name`, `teacher_id`, `description`, `schedule`), ensure immediate UI updates | M1 | Survey / Request |
| 4 | Supabase Storage Buckets Setup | Create `announcement_attachments`, `chat_attachments`, `voice_messages` buckets with secure RLS policies | M1 | Survey / Request |
| 5 | Messages Schema & Persistence | Align `messages` table schema with service payload (`attachment_name`, `attachment_url`, `message_type`, `audio_duration`) | M1 | Survey / Code Inspection |
| 6 | Fix Hidden "+ New Chat" Button | Fix Scaffold/Stack padding and FloatingActionButton positioning in `MessagesTab` so button clears `MeniscusNavBar` | M2 | Survey / Request |
| 7 | Redesign Chats Empty State & List | Create modern empty state with actionable button; add role badges, online status, and pinned section divider | M2 | Survey / Request |
| 8 | Redesign Home Page Announcements | Display at least 3 announcements via carousel/stacked cards without overflow; re-integrate admin center stats card | M2 | Survey / Request |
| 9 | Fix Dialog Contrast & Text Visibility | Fix `GoogleFonts.poppinsTextTheme` in dark mode, configure `dialogTheme` & `inputDecorationTheme`, high-contrast text | M2 | Survey / Request |
| 10 | Native Permissions Configuration | Update `AndroidManifest.xml`, `scripts/patch_manifest.py`, `Info.plist`, and `pubspec.yaml` with required storage, camera, audio permissions | M3 | Survey / Request |
| 11 | Announcement Device File Upload | Replace "Paste Link" with "Upload Document/Media from Device" using `file_picker`/`image_picker`, upload to Supabase storage | M3 | Survey / Request |
| 12 | Chat Attachment Device Upload | Remove "Paste Image URL" dialog; implement gallery/camera/document pickers with upload to `chat_attachments` and clickable bubble links | M3 | Survey / Request |
| 13 | Voice Message Recording & Playback | Real microphone recording with `record` (AAC `.m4a`), upload to `voice_messages`, real streaming playback with `audioplayers` | M3 | Survey / Request |
| 14 | Security & RLS Policy Enforcement | Comprehensive RLS audit across all tables and buckets; ensure zero service-role keys in client code | M4 | Survey / Request |
| 15 | Global Error Handling & UI Sanitization | Replace raw database error dumps (`PostgrestException`) with user-friendly messages via `cleanErrorMessage` | M4 | Survey / Request |
| 16 | Concurrency & Loading Spinners | Add loading spinners and disabled button states during async operations to prevent duplicate submissions | M4 | Survey / Request |
| 17 | End-to-End Acceptance Verification | Verify student persistence, halaqah creation, announcement attachment upload, chat attachments, and voice note recording/playback | M4 | Survey / Request |
| 18 | E2E Test Suite Creation | 4-Tier requirement-driven opaque-box test suite for automated CI regression testing | M5 (E2E) | Pattern Dual-Track |

---

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Backend & Database Architect | Announcements schema fix (`PGRST204`), Student cloud persistence & parent UUID fix, Halaqah RLS policies & payload alignment, Storage buckets creation & RLS | none | DONE |
| 2 | M2: UI/UX & Frontend Layout Specialist | Chats FAB position & clearance above `MeniscusNavBar`, Chats empty state & conversation list polish, Home screen >=3 announcements & admin stats card, Dialog dark-mode contrast | none | DONE |
| 3 | M3: Native Device Media, File Upload & Audio | Native permissions & `pubspec.yaml` packages, StorageService helper, Announcement device file picker & upload, Chat device media pickers, Voice message recording (`record`) & streaming playback (`audioplayers`) | M1 | DONE |
| 4 | M4: Security, QA & Deployment Readiness | Full RLS audit, zero hardcoded secrets verification, global error sanitization, async loading states, 4-point verification checklist execution | M1, M2, M3 | DONE |
| 5 | M5: E2E Testing Track | Automated test runner, 4 tiers of opaque-box feature, boundary, combinatorial, and scenario tests | none | DONE |

---

## Interface Contracts

### 1. StorageService ↔ Features (M1/M3)
```dart
class StorageService {
  static Future<String?> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    String? mimeType,
  });
  
  static String getPublicUrl({
    required String bucket,
    required String path,
  });
}
```

### 2. Announcement Model ↔ Storage & DB (M1/M3)
```dart
class Announcement {
  final String id;
  final String title;
  final String content;
  final String? attachmentUrl;
  final String? attachmentName;
  final String category;
  final String targetAudience;
  final String authorName;
  final bool isPinned;
  final DateTime createdAt;
}
```

### 3. Student Model & Service ↔ Supabase (M1)
```dart
class StudentService {
  Future<List<Student>> fetchStudentsFromCloud();
  Future<Map<String, dynamic>> addStudent({
    required String fullName,
    String? halaqahId,
    String? parentId,
    String? parentName,
    String? parentPhone,
    DateTime? dateOfBirth,
  });
}
```

### 4. Audio Pipeline ↔ Chat Messages (M3)
- Format: AAC in `.m4a` container.
- Storage bucket: `voice_messages`.
- Payload: `message_type: 'audio'`, `attachment_url: <public_url>`, `audio_duration: <seconds>`.

---

## Code Layout
- `lib/core/services/`
  - `supabase_service.dart`: Supabase client initialization, auth helpers, error sanitizer.
  - `storage_service.dart`: Supabase storage bucket upload/download handlers (M3).
  - `student_service.dart`: Student CRUD, cloud sync, local cache fallback (M1).
  - `halaqah_service.dart`: Halaqah CRUD, cloud persistence (M1).
  - `announcement_service.dart`: Announcement posting and retrieval (M1).
  - `messaging_service.dart`: Chat messages, media attachments, voice notes (M1, M3).
- `lib/core/theme/`
  - `app_theme.dart`: Global theme, dark mode textTheme, dialogTheme, inputDecorationTheme (M2).
  - `app_colors.dart`: Color tokens.
- `lib/screens/dashboard/`
  - `dashboard_screen.dart`: Shell scaffold and MeniscusNavBar dock (M2).
  - `tabs/home_tab.dart`: Home dashboard, announcements carousel, admin stats card (M2).
  - `tabs/messages_tab.dart`: Chats list, FAB positioning, empty state (M2).
- `lib/screens/announcements/`
  - `post_announcement_dialog.dart`: Device file picking and upload (M3).
- `lib/screens/messages/`
  - `chat_screen.dart`: Device media attachment, audio recorder & player widget (M3).
- `scripts/`
  - `apply_migrations.py` / `supabase_schema.sql`: SQL migration definitions and execution (M1).
  - `patch_manifest.py`: AndroidManifest injection (M3).
