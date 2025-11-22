# FreeCluely

FreeCluely is a stealth assistant for macOS designed for covert interaction with Google Gemini AI. The application operates as a minimalist overlay that doesn't draw attention, allowing you to receive AI assistance by analyzing your screen content in real-time.

## Installation and Setup

### 1. Get API Key
1. Visit [Google AI Studio](https://aistudio.google.com/).
2. Create an API key.

### 2. Configure the App
1. Create a file named `.env` in the project root folder (next to this file).
2. Paste your key into it:
   ```bash
   GEMINI_API_KEY=your_api_key_here
   GEMINI_MODEL=gemini-3-pro-preview
   ```

### 3. Build the App
Open a terminal in the project folder and run the build command:
```bash
./build_app.sh
```
This script will automatically download necessary dependencies and create the ready-to-use application.

### 4. Run
After a successful build, `FreeCluely.app` will appear in the `Build` folder. Launch it.

## Troubleshooting
- **Access Denied**: The application requires screen recording permissions to analyze content.
  Go to **System Settings > Privacy & Security > Screen Recording** and allow access for FreeCluely.
