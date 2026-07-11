# VESTRA

VESTRA - AI Smart Wardrobe Assistant by FranTal Company.

## Run now (Flutter + Hybrid backend)

### 1) Backend (FastAPI)

```powershell
cd backend
copy .env.example .env
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

If you want real remote inference on Fireworks, set `REMOTE_MODEL_API_KEY` in `backend/.env`.
Default remote model is `accounts/fireworks/models/kimi-k2p7-code` (vision-capable payload support is enabled when `imageUrl` is provided).

### 2) Flutter UI

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

Open `http://127.0.0.1:8080`, go to **Assistente IA**, enable **Usar backend FastAPI**, and set (for local backend dev):

`http://127.0.0.1:8000`

In production/demo, the app defaults to `https://vestraapi.frantalcompany.com`.

For vision requests, you can now select an image directly from your device in the AI screen (URL remains optional).

## Notes

- Without model API keys, the backend keeps working in deterministic simulation mode.
- With `REMOTE_MODEL_API_KEY`, remote route/fallback uses Fireworks.
- If no local model endpoint is configured, backend local-route requests automatically fall back to remote when Fireworks is available.
