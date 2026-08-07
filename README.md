# مساعد ذكي صوتي لتمكين ذوي الإعاقة الحركية — نظام محاسبة

مشروع تخرج: مساعد ذكي يعتمد على **Qwen/Llama** (عبر Ollama) و**Whisper** للصوت، لإدارة نظام محاسبة (عملاء، فواتير، منتجات) بالأوامر الصوتية والنصية باللغة العربية.

## المعمارية

```
Flutter App (صوت/نص)
       ↓
NestJS Backend (Auth, CRUD, AI Agent)
       ↓                    ↓
PostgreSQL              Ollama (Qwen2.5)
       ↑
Python AI Service (Whisper STT + Edge TTS)
```

## المتطلبات

| الأداة | الإصدار |
|--------|---------|
| Node.js | 18+ |
| Python | 3.10+ |
| Flutter | 3.x |
| PostgreSQL | 14+ |
| Ollama | latest |

## التثبيت السريع (Windows)

### 1. PostgreSQL

ثبّت PostgreSQL من [postgresql.org](https://www.postgresql.org/download/windows/) أو شغّل Docker:

```bash
docker compose up -d
```

أنشئ قاعدة البيانات `ai_accessibility` إذا لم تستخدم Docker.

### 2. Ollama + نموذج Qwen

```bash
# ثبّت Ollama من https://ollama.com
ollama pull qwen2.5:7b
ollama serve
```

### 3. Backend (NestJS)

```bash
cd backend
copy .env.example .env
npm install
npx prisma generate
npx prisma migrate dev --name init
npm run prisma:seed
npm run start:dev
```

يعمل على: `http://localhost:3000/api`

### 4. AI Voice Service (Python)

```bash
cd ai-service
setup.bat
start.bat
```

يعمل على: `http://localhost:8000`

### 5. تطبيق Flutter

```bash
cd mobile
flutter pub get
flutter run
```

> **Android Emulator:** يستخدم `10.0.2.2:3000` تلقائياً  
> **Windows Desktop:** يستخدم `localhost:3000`

## حسابات تجريبية

| الدور | البريد | كلمة المرور |
|-------|--------|-------------|
| مدير | admin@accounting.local | admin123 |
| مستخدم | user@accounting.local | user123 |

## أمثلة أوامر

- «أريد معرفة فواتير العميل محمد في الشهر الماضي»
- «اعرض آخر فاتورة لعلي»
- «ما ملخص المحاسبة؟»
- «أنشئ تقريراً عن الفواتير المعلقة»
- «اعرض قائمة المنتجات»

## API الرئيسية

| Method | Endpoint | الوصف |
|--------|----------|-------|
| POST | /api/auth/login | تسجيل الدخول |
| POST | /api/ai/chat | محادثة مع المساعد |
| POST | /api/voice/speech-to-text | تحويل صوت → نص |
| POST | /api/voice/text-to-speech | تحويل نص → صوت |
| GET | /api/invoices/summary | ملخص المحاسبة |
| GET | /api/customers | العملاء |
| GET | /api/invoices | الفواتير |

## هيكل المشروع

```
AIAccessibilityAssistant/
├── backend/          # NestJS + Prisma + AI Agent
├── ai-service/       # Python: Whisper + Edge TTS
├── mobile/           # Flutter App
├── docker-compose.yml
└── README.md
```

## التقنيات

| المجال | التقنية |
|--------|---------|
| Mobile | Flutter |
| Backend | NestJS |
| Database | PostgreSQL + Prisma |
| LLM | Ollama (Qwen2.5) |
| AI Integration | Function Calling + Schema Context |
| STT | faster-whisper |
| TTS | edge-tts (Arabic) |
| Auth | JWT + RBAC |

## استكشاف الأخطاء

**Ollama غير متصل:** تأكد من `ollama serve` و `ollama pull qwen2.5:7b`

**Whisper بطيء:** النموذج `base` مناسب للتطوir. للدقة الأعلى غيّر إلى `small` في `ai-service/.env`

**Flutter لا يتصل:** تحقق من عنوان API في `mobile/lib/config/api_config.dart`

**PostgreSQL:** تحقق من `DATABASE_URL` في `backend/.env`

## الترخيص

مشروع تعليمي — مشروع تخرج
