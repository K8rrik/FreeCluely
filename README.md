[![Ru](https://img.shields.io/badge/lang-ru-green.svg)](README_RU.md)

# FreeCluely

FreeCluely is a stealth assistant for macOS designed for covert interaction with Google Gemini AI. The application operates as a minimalist overlay that doesn't draw attention, allowing you to receive AI assistance by analyzing your screen content in real-time.

## Features

- **Stealth Overlay**: Minimalist design that stays out of your way.
- **Screen Analysis**: Analyze screen content to get relevant AI assistance.
- **Voice Mode**: Real-time speech-to-text transcription using Deepgram (Nova-2 model).
- **Smart Suggestions**: Proactive AI suggestions based on your conversation context.
- **Transcription Window**: Dedicated terminal-like window for live transcription logs.
- **Global Hotkey**: Quickly access the assistant from anywhere.

## Installation and Setup

### 1. Get API Keys
1. **Google Gemini**: Visit [Google AI Studio](https://aistudio.google.com/) and create an API key.
2. **Deepgram**: Visit [Deepgram Console](https://console.deepgram.com/) and create an API key (required for Voice Mode).

### 2. Configure the App
1. Create a file named `.env` in the project root folder (next to this file).
2. Paste your keys into it:
   ```bash
   GEMINI_API_KEY=your_gemini_key_here
   GEMINI_MODEL=gemini-3-pro-preview
   GEMINI_FAST_MODEL=gemini-2.5-flash // Fast model for conversation responses 
   DEEPGRAM_API_KEY=your_deepgram_key_here
   ```

### 3. Build the App
Open a terminal in the project folder and run the build command:
```bash
./build_app.sh
```
This script will automatically download necessary dependencies and create the ready-to-use application.

### 4. Run
After a successful build, `FreeCluely.app` will appear in the `Build` folder. Launch it.

## Hotkeys

- **Cmd + /**: Global hotkey to show window and focus input.
- **Cmd + Shift + A**: Analyze screen content and get AI assistance.
- **Cmd + Shift + W**: Toggle application visibility.
- **Cmd + Shift + C**: Clear current session and start new.
- **Cmd + Shift + H**: Toggle history view.
- **Cmd + Arrow Keys**: Move the application window.

## Troubleshooting
- **Access Denied**: The application requires screen recording permissions to analyze content and capture system audio.
  Go to **System Settings > Privacy & Security > Screen Recording** and allow access for FreeCluely.
- **Voice Mode Issues**: Voice Mode requires macOS 13.0 or later. Ensure your Deepgram API key is correctly set in `.env`.
