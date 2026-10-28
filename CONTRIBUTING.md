# Contributing to BitChord iOS

We welcome contributions to BitChord iOS. Please review the guidelines below to ensure code quality, consistency, and compliance with project standards.

---

## Code Quality Standards

1. **Swift Version:** Code must compile with Swift 5.9 and target iOS 16.0 or newer.
2. **Design Preferences:**
   * Strictly no glassmorphism or excessive background blur. Use clean, professional flat design with solid surfaces and system colors.
   * Maintain a minimum tap target of 44x44 points for all buttons and interactive controls.
   * Ensure text meets WCAG AA contrast requirements (minimum 4.5:1 for body copy).
3. **Copywriting and Documentation:**
   * Do not use em dashes (`—`). Use commas, periods, colons, or parentheses instead.
   * Avoid AI marketing buzzwords (e.g. "revolutionary", "seamless", "cutting-edge"). Write direct, functional sentences.
   * Do not write decorative code banner comments (e.g. `// =======================`). Keep comments focused on constraints, invariants, and platform traps.
4. **Data Handling:**
   * Every screen displaying dynamic data must implement three explicit states: Loading, Empty, and Error.
   * Interactive controls must have a real action. Do not leave dead buttons or non-functional placeholders.

---

## Development Workflow

### Opening in Xcode
1. Clone the repository:
   ```bash
   git clone https://github.com/vTrxn/BitChord-iOS-Test-.git
   cd BitChord-iOS-Test-
   ```
2. Open `BitChord.xcodeproj` directly in Xcode 15 or newer.
3. Select your development team under **Signing & Capabilities**.
4. Choose an iOS Simulator or connected physical device and run (`Cmd + R`).

### Regenerating Project Files
If you add or remove Swift source files:
* You can update `project.yml` and run `xcodegen generate` (requires XcodeGen installed via Homebrew).
* Alternatively, run `python generate_project.py` to deterministically regenerate `BitChord.xcodeproj/project.pbxproj`.

---

## Submitting Pull Requests

1. Fork the repository and create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. Verify that the project builds cleanly without warnings:
   ```bash
   xcodebuild -project BitChord.xcodeproj -scheme BitChord -destination 'generic/platform=iOS' build
   ```
3. Commit your changes with clear, descriptive commit messages.
4. Push to your fork and submit a Pull Request against the `main` branch.
