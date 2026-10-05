# Kheyrukum (خَيْرُكُمْ) — Parent-Teacher Quranic Portal Mobile App

A modern, highly animated mobile application built with **Flutter**, designed specifically for Quranic schools and parent-teacher collaboration.

---

## 🌟 Core Features & Implementations

### 1. Animated Splash & Onboarding (`SplashScreen` & `SplashPainter`)
Total duration: **3.5 seconds** with a coordinated multi-phase staggered timeline:
- **Phase 1: The Journey (0.0s – 1.5s)**: An amber (`#FFC107`) to soft teal (`#00BCD4`) glowing flight trail sweeping across the screen using dynamic `PathMetric.extractPath()`, dual-pass Gaussian glow painting, and a leading flight spark.
- **Phase 2: The Connection (1.5s – 2.0s)**: Dual interlocking glowing rings representing the Parent and Teacher in warm amber and soft teal, drawing with sweep arcs and interlocking intersection highlights.
- **Phase 3: The Core (2.0s – 2.5s)**: The rings converge and morph into an illuminated Quran / open book with golden rays and a subtle focus pulse ($1.0 \to 1.12 \times \to 1.0$).
- **Phase 4: Text Reveal (2.5s – 3.0s)**: Bold app title **"Kheyrukum"** (36sp) and the revered Quranic Hadith tagline **"خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ"** (16sp, 70% opacity) fade in and slide up gracefully.
- **Phase 5: Navigation (3.5s)**: Automatic transition to `/dashboard`.

### 2. Fluid "Meniscus" Physics Bottom Navigation Bar (`MeniscusNavBar`)
- **Pill-shaped Floating Container**: Elevated `#1E293B` container hovering over deep navy `#0F172A`.
- **Dynamic Bezier Notch / Meniscus**: Calculated with $C^1$-continuous cubic Bezier curves in `MeniscusPainter`. The notch moves dynamically in real-time as the user drags or taps.
- **Glowing Bead Indicator**: 3D jewel aesthetic with radial gradients, glass specular highlights, and active tab icons.
- **Drag-to-Slide Interaction**: Direct tracking via `GestureDetector.onPanUpdate`.
- **Spring Snapping**: Uses `AnimationController.unbounded` paired with `SpringSimulation` (`stiffness: 380`, `damping: 24`, `mass: 1.0`) for organic, tactile snapping.
- **Dynamic Screen Content**: Screen header and tab view crossfade dynamically using state management.

---

## 🚀 Running the Project

```bash
# Get dependencies
flutter pub get

# Run on connected device or emulator
flutter run
```

## 📐 Project Structure

```
lib/
├── core/
│   ├── routes/
│   │   └── app_routes.dart
│   └── theme/
│       ├── app_colors.dart
│       └── app_theme.dart
├── screens/
│   ├── dashboard/
│   │   ├── dashboard_screen.dart
│   │   └── tabs/
│   │       ├── home_tab.dart
│   │       ├── homework_tab.dart
│   │       ├── messages_tab.dart
│   │       └── settings_tab.dart
│   └── splash/
│       ├── splash_screen.dart
│       └── widgets/
│           └── splash_painter.dart
├── widgets/
│   ├── glowing_bead.dart
│   ├── meniscus_nav_bar.dart
│   └── meniscus_painter.dart
└── main.dart
```
