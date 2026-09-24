# Sound Painter: Color My Voice
## Game Design Document & Engineering Blueprint

---

## 1. Executive Summary & Vision

**Sound Painter: Color My Voice** is an interactive, voice-controlled educational game designed for young children aged 3 to 6. The core gameplay translates vocal mechanics—pitch, volume, and sustained vowel phonemes—into real-time art and responsive environment filling.

```
       [ Child's Voice ]
               │
      (Volume / Pitch / Vowel)
               │
               ▼
┌──────────────────────────────┐
│   Sound Painter Engine       │
│  - Real-time Audio DSP       │
│  - HSL Palette Interpolation │
│  - Vector/Particle Canvas    │
└──────────────┬───────────────┘
               │
      (Visual Art Output)
               │
               ▼
  [ Glowing Canvas & Characters ]
```

* **Core Target Audience:** Ages 3–6 (Early Childhood Development, Pre-K to Kindergarten).
* **Primary Learning Pillars:**
  1. Auditory Processing & Pitch Discrimination.
  2. Phonics & Vowel Sound Production ($/a/$, $/e/$, $/i/$, $/o/$, $/u/$).
  3. Fine Motor Control & Spatial Awareness.
* **Platforms:** Mobile & Tablet (Android & iOS).
* **Primary Tech Stack:** Flutter, `flutter_audio_capture`, Custom Painter, and SQLite.

---

## 2. Target Audience & Pedagogical Framework

```
  AGE 3-4 (Exploration)                  AGE 5-6 (Structured)
┌────────────────────────┐            ┌────────────────────────┐
│ • Sensory Cause-Effect │ ─────────► │ • Target Phonics Match │
│ • Free Canvas Drawing  │            │ • Animal Outlines      │
│ • Motor Skill Building │            │ • Vocal Pitch Tuning   │
└────────────────────────┘            └────────────────────────┘
```

### Age Group 3–4: Sensory Exploration
* **Cognitive Focus:** Immediate feedback loops connecting vocal exertion with visual transformation.
* **UI Constraint:** Zero text, full tap-and-play interface, large interactive hit boxes ($>64 \times 64 \text{ dp}$).

### Age Group 5–6: Phonetic & Pitch Control
* **Cognitive Focus:** Sound isolation, controlled pitch regulation, and phoneme identification.
* **UI Constraint:** Visual icons, low-friction level progression, and direct visual feedback for sound matching.

---

## 3. Character Roster & Visual Style

### Art Style Strategy
* **Style:** Warm, pastel-neon hybrid on dark canvas backgrounds (reducing eye strain while highlighting particle effects).
* **Color Psychology:** Soft purples and deep blues for background ambiance, high-saturation primaries and warm tones for user-generated particles.

```
      +------------------+                    +------------------+
      |  Pip the Penguin |                    |  Ollie the Owl   |
      |   (Pitch Expert) |                    |  (Volume Expert) |
      +--------+---------+                    +--------+---------+
               |                                       |
               +-------------------+-------------------+
                                   |
                         +---------+--------+
                         |  Aria the Turtle |
                         | (Formant Expert) |
                         +------------------+
```

### Character Specifications

#### 1. Pip the Penguin (Pitch Guide)
* **Visual Role:** Dynamic pitch mentor.
* **Visual Traits:** Soft round penguin wearing a glowing scarf that changes color according to Pip's current pitch.
* **Animation States:**
  * *Idle:* Bounces gently on an ice block.
  * *Low Pitch:* Shrinks down cozy into its scarf (Deep Blue/Purple aura).
  * *High Pitch:* Leaps up with wings outstretched (Warm Pink/Red aura).

#### 2. Ollie the Owl (Volume Guide)
* **Visual Role:** Amplitude and duration mentor.
* **Visual Traits:** Feathered owl with broad, expressive eyes and glowing wings.
* **Animation States:**
  * *Whisper Mode:* Eyes open wide, wings wrapped tight (Fine brush traces).
  * *Loud Mode:* Wings flap outwards, throwing glowing feather particles (Thick brush strokes).

#### 3. Aria the Turtle (Phonics Guide)
* **Visual Role:** Formant vowel guide.
* **Visual Traits:** Wise, friendly sea turtle whose shell features glowing geometric pattern segments.
* **Animation States:**
  * *Listening:* Tilts head forward toward the child.
  * *Vowel Success:* Shell patterns light up progressively as correct phonemes are held.

---

## 4. Game Modes & Screen Flow

```
                     ┌──────────────────┐
                     │   Splash Screen  │
                     └────────┬─────────┘
                              │
                     ┌────────▼─────────┐
                     │   Main Menu      │
                     └────────┬─────────┘
                              │
       ┌──────────────────────┼──────────────────────┐
       │                      │                      │
┌──────▼───────┐       ┌──────▼───────┐       ┌──────▼───────┐
│ Free Canvas  │       │ Phonics Mode │       │ Parent Dashboard│
└──────────────┘       └──────────────┘       └──────────────┘
```

### Screen Map & Specifications

#### Screen 1: Splash & Permission Onboarding
* **Visual Layout:** Clean canvas background with Pip floating on a balloon.
* **UX Flow:** Requests microphone permissions with child-friendly audio prompts (*"Pip needs to hear your voice to paint!"*).

#### Screen 2: Main Navigation Hub
* **Visual Layout:** Three distinct, large floating world buttons:
  1. **Free Canvas:** A glowing color palette wheel.
  2. **Phonics Safari:** An interactive jungle map featuring Aria and Ollie.
  3. **Parent / Educator Zone:** Hidden behind a multi-touch safety gate.

#### Screen 3: Free Canvas Mode
* **UI Overhead:** 
  * *Top-Left:* Home button.
  * *Top-Right:* Clear Canvas / Trash icon.
  * *Bottom Bar:* Floating live audio HUD with real-time waveform feedback.
* **Interactive Behavior:** Continuous vocalization generates smooth, flowing particle tracks across the screen.

#### Screen 4: Phonics Safari (Level Screen)
* **UI Overhead:** 
  * Centered vector drawing of an uncolored animal or object (e.g., an Apple for $/a/$).
  * Aria sits in the bottom corner holding a visual mouth-position diagram.
* **Mechanic:** The child sustains the targeted phoneme to color in the illustration progressively.

#### Screen 5: Parent & Educator Dashboard
* **Access Control:** Parent Gate (Requires solving a math problem like *"Tap the number 14"* or a 3-finger long press).
* **Metrics Tracked:**
  * Daily play session durations.
  * Vocal pitch frequency distributions (Hz).
  * Mastered phonemes ($/a/$, $/e/$, $/i/$, $/o/$, $/u/$).
  * Toggle options for background music volume and mic sensitivity calibration.

---

## 5. Technical Architecture & Audio DSP Pipeline

```
  [ Mic Input Buffer ]
           │
           ▼
  [ AudioProcessor ]
     ├── 1. RMS Calculation (Volume -> Line Thickness)
     ├── 2. Autocorrelation / YIN (Pitch -> HSL Color)
     └── 3. FFT Formant Analysis (Vowel Phoneme Recognition)
           │
           ▼
  [ Game State Controller ]
           │
           ▼
  [ CustomPainter Engine ] ──► (Particle & Vector Rendering)
```

### Audio Data Flow Specifications
* **Sample Rate:** $16\text{ kHz}$, 16-bit Mono PCM.
* **Buffer Size:** $2048\text{ samples}$ ($\approx 128\text{ ms}$ chunks for low latency).

### DSP Equations & Conversions

#### 1. Volume / Amplitude Calculation (RMS)
$$\text{RMS} = \sqrt{\frac{1}{N} \sum_{i=1}^{N} x_i^2}$$

$$\text{Volume Normalized} = \text{Clamp}\left(\frac{\text{RMS}}{\text{RMS}_{\text{max}}}, 0.0, 1.0\right)$$

#### 2. Pitch Detection via Autocorrelation
$$\text{Autocorrelation}(k) = \sum_{i=0}^{N-k-1} x_i \cdot x_{i+k}$$

The lag $k$ yielding the highest value within the human vocal window ($100\text{ Hz} \le f \le 800\text{ Hz}$) defines the fundamental pitch:

$$f_0 = \frac{\text{Sample Rate}}{k_{\text{best}}}$$

#### 3. Pitch-to-HSL Color Mapping
```dart
double mapPitchToHue(double pitchHz) {
  const double minHz = 100.0; // Low voice / Deep purple
  const double maxHz = 700.0; // High voice / Warm red
  double clamped = pitchHz.clamp(minHz, maxHz);
  double norm = (clamped - minHz) / (maxHz - minHz);
  
  // Hue scale: 260° (Blue/Purple) down to 0° (Red)
  return (1.0 - norm) * 260.0;
}
```

---

## 6. Project Directory Structure

```
sound_painter/
├── android/
├── ios/
├── assets/
│   ├── audio/
│   │   ├── music/
│   │   └── sfx/
│   ├── chara/
│   │   ├── pip/
│   │   ├── ollie/
│   │   └── aria/
│   └── icons/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── audio/
│   │   │   ├── audio_processor.dart
│   │   │   ├── pitch_detector.dart
│   │   │   └── formant_analyzer.dart
│   │   ├── constants/
│   │   │   ├── app_colors.dart
│   │   │   └── sound_constants.dart
│   │   └── theme/
│   ├── models/
│   │   ├── paint_stroke.dart
│   │   ├── phonics_level.dart
│   │   └── user_progress.dart
│   ├── views/
│   │   ├── canvas/
│   │   │   ├── sound_painter_canvas.dart
│   │   │   └── particle_painter.dart
│   │   ├── dashboard/
│   │   │   └── parent_dashboard_view.dart
│   │   ├── home/
│   │   │   └── main_menu_view.dart
│   │   ├── onboarding/
│   │   │   └── mic_permission_view.dart
│   │   └── safari/
│   │       └── phonics_safari_view.dart
│   ├── widgets/
│   │   ├── audio_hud.dart
│   │   ├── parent_gate_dialog.dart
│   │   └── character_avatar.dart
│   └── services/
│       ├── database_service.dart
│       └── storage_service.dart
└── pubspec.yaml
```

---

## 7. Complete Core Implementation Code

### 1. `lib/models/paint_stroke.dart`

```dart
import 'package:flutter/material.dart';

class PaintParticle {
  final Offset position;
  final Color color;
  final double radius;
  final double opacity;

  PaintParticle({
    required this.position,
    required this.color,
    required this.radius,
    this.opacity = 1.0,
  });
}
```

### 2. `lib/core/audio/audio_processor.dart`

```dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

class AudioAnalysisResult {
  final double volume;
  final double frequencyHz;
  final Color mappedColor;
  final double strokeWidth;
  final String detectedVowel;

  AudioAnalysisResult({
    required this.volume,
    required this.frequencyHz,
    required this.mappedColor,
    required this.strokeWidth,
    required this.detectedVowel,
  });
}

class AudioProcessor {
  final int sampleRate;
  static const double silenceThreshold = 0.02;

  AudioProcessor({this.sampleRate = 16000});

  AudioAnalysisResult processPcmBuffer(Uint8List byteBuffer) {
    final Int16List samples = byteBuffer.buffer.asInt16List();
    if (samples.isEmpty) {
      return AudioAnalysisResult(
        volume: 0,
        frequencyHz: 0,
        mappedColor: Colors.transparent,
        strokeWidth: 0,
        detectedVowel: '',
      );
    }

    // 1. RMS Volume Calculation
    double sumSquares = 0.0;
    for (int i = 0; i < samples.length; i++) {
      double norm = samples[i] / 32768.0;
      sumSquares += norm * norm;
    }
    double rms = math.sqrt(sumSquares / samples.length);
    double normalizedVol = (rms / 0.4).clamp(0.0, 1.0);

    if (rms < silenceThreshold) {
      return AudioAnalysisResult(
        volume: 0,
        frequencyHz: 0,
        mappedColor: Colors.transparent,
        strokeWidth: 0,
        detectedVowel: '',
      );
    }

    // 2. Pitch Detection via Autocorrelation
    double pitch = _detectPitch(samples, sampleRate);
    Color color = _pitchToColor(pitch);
    double stroke = 6.0 + (normalizedVol * 42.0);
    String vowel = _estimateVowelFormant(samples, sampleRate);

    return AudioAnalysisResult(
      volume: normalizedVol,
      frequencyHz: pitch,
      mappedColor: color,
      strokeWidth: stroke,
      detectedVowel: vowel,
    );
  }

  double _detectPitch(Int16List samples, int rate) {
    int minLag = (rate / 800).floor();
    int maxLag = (rate / 100).floor();
    if (maxLag >= samples.length) maxLag = samples.length - 1;

    double maxCorr = -1.0;
    int bestLag = -1;

    for (int lag = minLag; lag <= maxLag; lag++) {
      double corr = 0.0;
      for (int i = 0; i < samples.length - lag; i++) {
        corr += (samples[i] / 32768.0) * (samples[i + lag] / 32768.0);
      }
      if (corr > maxCorr) {
        maxCorr = corr;
        bestLag = lag;
      }
    }

    return (bestLag != -1 && maxCorr > 0.15) ? (rate / bestLag) : 0.0;
  }

  Color _pitchToColor(double pitchHz) {
    if (pitchHz <= 0) return Colors.grey;
    double clamped = pitchHz.clamp(100.0, 700.0);
    double norm = (clamped - 100.0) / 600.0;
    double hue = (1.0 - norm) * 260.0;
    return HSVColor.fromAHSV(1.0, hue, 0.85, 0.95).toColor();
  }

  String _estimateVowelFormant(Int16List samples, int rate) {
    // Basic Formant Estimation Placeholder
    return '/a/';
  }
}
```

### 3. `lib/views/canvas/particle_painter.dart`

```dart
import 'package:flutter/material.dart';
import '../../models/paint_stroke.dart';

class ParticleCanvasPainter extends CustomPainter {
  final List<PaintParticle> particles;

  ParticleCanvasPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.opacity)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.0);

      canvas.drawCircle(particle.position, particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticleCanvasPainter oldDelegate) => true;
}
```

---

## 8. Google Play Store Publishing Checklist

```
┌─────────────────────────────────────────────────────────────┐
│                    Google Play Readiness                    │
├──────────────────────────────┬──────────────────────────────┤
│  Data Safety & Privacy       │  Families Policy Compliance  │
│  - Zero Ad Tracking          │  - Neutral Age Screen Gate   │
│  - Local Micro Processing    │  - Protected Parent Settings │
└──────────────────────────────┴──────────────────────────────┘
```

### 1. Data Safety & Privacy Policy Setup
* **Microphone Usage Justification:** State explicitly in Play Console: *"Microphone access is processed strictly on-device in real-time to translate vocal volume and pitch into visual graphics. Audio data is never recorded, stored, or transmitted over any network."*
* **Target Audience:** Declare target age groups **3–5** and **6–8** in the Google Play Console Target Audience section.

### 2. Google Play Families Policy Requirements
* **Zero Advertising / COPPA Compliance:** No third-party ad networks or tracking SDKs (e.g., disable standard AdMob, Facebook Audience Network).
* **Parent Gate:** All external links, in-app purchases, or settings menus must be protected by a secure Parent Gate.
* **App Content Rating:** Complete the IARC questionnaire to obtain an **Everyone / PEGI 3** rating.

### 3. Android Build & Release Configuration

#### `android/app/build.gradle`
```groovy
android {
    compileSdkVersion 34

    defaultConfig {
        applicationId "com.homilabs.soundpainter"
        minSdkVersion 24
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }

    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

#### `android/app/src/main/AndroidManifest.xml`
```xml
<manifest xmlns:android="http://schemas.android.com/app/res/android"
    package="com.homilabs.soundpainter">

    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />

    <application
        android:label="Sound Painter"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
```

---

## 9. Store Assets & Submission Specs

| Asset Type | Specifications | Requirements |
| :--- | :--- | :--- |
| **App Icon** | $512 \times 512 \text{ px}$ PNG | Vibrant, high-contrast, featuring Pip surrounded by glowing paint strokes. |
| **Feature Graphic** | $1024 \times 500 \text{ px}$ PNG/JPEG | Shows the game tagline: *"Color the World with Your Voice!"* |
| **Phone Screenshots** | Min 2 screenshots, 16:9 or 9:16 aspect ratio | Display Free Canvas and Phonics Safari modes clearly. |
| **Tablet Screenshots** | Min 1 7-inch & 1 10-inch screenshot | High-resolution canvas views showing particle detail. |