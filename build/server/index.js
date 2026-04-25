import express from 'express';
import cors from 'cors';
import session from 'express-session';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { initializeDatabase } from './database.js';
import authRoutes from './routes/auth.js';
import wishlistRoutes from './routes/wishlist.js';
import collaborativeRoutes from './routes/collaborative.js';
const app = express();
const PORT = Number(process.env.PORT || 5001);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const isProduction = process.env.NODE_ENV === 'production';
const sessionCookieSecure = process.env.SESSION_COOKIE_SECURE === 'true';
function resolveClientDistPath() {
    const candidates = [
        path.resolve(__dirname, '../dist'),
        path.resolve(__dirname, '../../dist')
    ];
    for (const candidate of candidates) {
        if (fs.existsSync(path.join(candidate, 'index.html'))) {
            return candidate;
        }
    }
    return null;
}
// Middleware
app.use(cors({
    origin: (origin, callback) => {
        const allowedOriginPatterns = [
            /^http:\/\/(localhost|127\.0\.0\.1):\d+$/,
            /^https?:\/\/(?:[a-zA-Z0-9-]+\.)*gwsapp\.net$/,
        ];
        if (!origin || allowedOriginPatterns.some((pattern) => pattern.test(origin))) {
            callback(null, true);
            return;
        }
        callback(new Error('Not allowed by CORS'));
    },
    credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
// Session configuration
app.use(session({
    secret: process.env.SESSION_SECRET || 'ourwish-secret-key',
    resave: false,
    saveUninitialized: true,
    cookie: {
        // For desktop Electron and local dev over HTTP, this must remain false.
        // Set SESSION_COOKIE_SECURE=true explicitly only when serving over HTTPS.
        secure: sessionCookieSecure,
        httpOnly: true,
        sameSite: 'lax',
        maxAge: 24 * 60 * 60 * 1000 // 24 hours
    }
}));
// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/wishlist', wishlistRoutes);
app.use('/api/collaborative', collaborativeRoutes);
// Health check
app.get('/api/health', (req, res) => {
    res.json({ status: 'OK' });
});
if (isProduction) {
    const clientDistPath = resolveClientDistPath();
    if (clientDistPath) {
        app.use(express.static(clientDistPath));
        app.get('*', (req, res, next) => {
            if (req.path.startsWith('/api/')) {
                next();
                return;
            }
            res.sendFile(path.join(clientDistPath, 'index.html'));
        });
    }
    else {
        console.warn('Production mode enabled but dist/index.html was not found');
    }
}
// Initialize database and start server
initializeDatabase()
    .then(() => {
    app.listen(PORT, () => {
        console.log(`Server running on http://localhost:${PORT}`);
    });
})
    .catch((error) => {
    console.error('Failed to initialize database:', error);
    process.exit(1);
});
export default app;
