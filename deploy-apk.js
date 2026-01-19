#!/usr/bin/env node

/**
 * APK Update Deployment Script für streameee Fire TV App
 *
 * Dieses Skript:
 * 1. Baut die Release-APK (optional mit --build Flag)
 * 2. Liest Version aus pubspec.yaml
 * 3. Erstellt/aktualisiert manifest.json
 * 4. Lädt APK + manifest.json auf den Server
 *
 * Usage:
 *   node deploy-apk.js              # Nur hochladen (APK muss existieren)
 *   node deploy-apk.js --build      # APK bauen und hochladen
 *   node deploy-apk.js --notes "Release Notes hier"
 */

const ftp = require('basic-ftp');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const https = require('https');
require('dotenv').config({ path: '.env.ftp' });

// Konfiguration
const FTP_CONFIG = {
    host: process.env.FTP_HOST,
    user: process.env.FTP_USER,
    password: process.env.FTP_PASSWORD,
    port: parseInt(process.env.FTP_PORT || '21'),
    secure: process.env.FTP_SECURE === 'true'
};

const REMOTE_UPDATE_DIR = '/streameee/update';
const REMOTE_DL_DIR = '/streameee/dl';
const APK_SOURCE_PATH = 'build/app/outputs/flutter-apk/app-release.apk';

// Cloudflare Konfiguration
const CLOUDFLARE_ZONE_ID = process.env.CLOUDFLARE_ZONE_ID;
const CLOUDFLARE_API_TOKEN = process.env.CLOUDFLARE_API_TOKEN;

// Argumente parsen
const args = process.argv.slice(2);
const shouldBuild = args.includes('--build');
const forceUpdate = args.includes('--force');
const notesIndex = args.indexOf('--notes');
const releaseNotes = notesIndex !== -1 ? args[notesIndex + 1] : null;

/**
 * Version aus pubspec.yaml lesen
 */
function getVersionFromPubspec() {
    const pubspecPath = path.join(__dirname, 'pubspec.yaml');
    const content = fs.readFileSync(pubspecPath, 'utf8');

    // version: 1.0.0+1 -> { version: "1.0.0", versionCode: 1 }
    const versionMatch = content.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)/m);
    if (!versionMatch) {
        throw new Error('Version nicht in pubspec.yaml gefunden');
    }

    return {
        version: versionMatch[1],
        versionCode: parseInt(versionMatch[2])
    };
}

/**
 * Manifest.json erstellen/aktualisieren
 */
function createManifest(version, versionCode, notes) {
    const manifest = {
        version: version,
        versionCode: versionCode,
        apkUrl: `https://streameee.com/update/streameee-v${version}.apk`,
        releaseNotes: notes || `- Version ${version}`,
        forceUpdate: forceUpdate
    };

    const manifestPath = path.join(__dirname, 'update-manifest.json');
    fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));

    return manifestPath;
}

/**
 * APK bauen
 */
function buildApk() {
    console.log('🔨 Baue Release-APK...');
    try {
        execSync('flutter build apk --release', {
            stdio: 'inherit',
            cwd: __dirname
        });
        console.log('✅ APK erfolgreich gebaut');
    } catch (error) {
        console.error('❌ APK Build fehlgeschlagen');
        process.exit(1);
    }
}

/**
 * Cloudflare Cache für bestimmte URLs purgen
 */
async function purgeCloudflareCache(urls) {
    if (!CLOUDFLARE_ZONE_ID || !CLOUDFLARE_API_TOKEN) {
        console.log('⚠️  Cloudflare nicht konfiguriert, überspringe Cache-Purge');
        return false;
    }

    return new Promise((resolve) => {
        const data = JSON.stringify({ files: urls });

        const options = {
            hostname: 'api.cloudflare.com',
            port: 443,
            path: `/client/v4/zones/${CLOUDFLARE_ZONE_ID}/purge_cache`,
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${CLOUDFLARE_API_TOKEN}`,
                'Content-Type': 'application/json',
                'Content-Length': data.length
            }
        };

        const req = https.request(options, (res) => {
            let body = '';
            res.on('data', chunk => body += chunk);
            res.on('end', () => {
                try {
                    const response = JSON.parse(body);
                    if (response.success) {
                        console.log('✅ Cloudflare Cache erfolgreich geleert');
                        resolve(true);
                    } else {
                        console.log('⚠️  Cloudflare Fehler:', response.errors?.[0]?.message || 'Unbekannt');
                        resolve(false);
                    }
                } catch (e) {
                    console.log('⚠️  Cloudflare Antwort konnte nicht gelesen werden');
                    resolve(false);
                }
            });
        });

        req.on('error', (e) => {
            console.log('⚠️  Cloudflare Request fehlgeschlagen:', e.message);
            resolve(false);
        });

        req.write(data);
        req.end();
    });
}

/**
 * Dateien auf FTP hochladen
 */
async function uploadToFtp(apkPath, manifestPath, version) {
    const client = new ftp.Client();
    client.ftp.verbose = false;

    try {
        console.log('🔌 Verbinde mit FTP-Server...');
        await client.access(FTP_CONFIG);
        console.log('✅ Verbindung hergestellt!');

        // Update-Verzeichnis erstellen
        console.log('📁 Erstelle Verzeichnis:', REMOTE_UPDATE_DIR);
        await client.ensureDir(REMOTE_UPDATE_DIR);

        // 1. APK für kurzen Download-Link (streameee.com/app)
        console.log('📤 Lade APK hoch: /dl/streameee.apk (kurzer Link)...');
        await client.ensureDir(REMOTE_DL_DIR);
        await client.uploadFrom(apkPath, path.posix.join(REMOTE_DL_DIR, 'streameee.apk'));
        console.log('✅ APK für Download-Link hochgeladen');

        // 2. Versionierte APK für Update-System
        const remoteApkName = `streameee-v${version}.apk`;
        console.log(`📤 Lade APK hoch: /update/${remoteApkName} (Update-System)...`);
        await client.uploadFrom(apkPath, path.posix.join(REMOTE_UPDATE_DIR, remoteApkName));
        console.log('✅ Versionierte APK hochgeladen');

        // 3. Manifest hochladen
        console.log('📤 Lade manifest.json hoch...');
        await client.uploadFrom(manifestPath, path.posix.join(REMOTE_UPDATE_DIR, 'manifest.json'));
        console.log('✅ manifest.json hochgeladen');

        // Cloudflare Cache purgen
        console.log('🌐 Leere Cloudflare Cache...');
        const urlsToPurge = [
            'https://streameee.com/dl/streameee.apk',
            'https://streameee.com/update/manifest.json',
            `https://streameee.com/update/${remoteApkName}`
        ];
        await purgeCloudflareCache(urlsToPurge);

        console.log('\n🎉 Deployment abgeschlossen!');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log(`🔗 Download:  https://streameee.com/app (kurzer Link)`);
        console.log(`📱 APK:       https://streameee.com/update/${remoteApkName}`);
        console.log(`📋 Manifest:  https://streameee.com/update/manifest.json`);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    } catch (error) {
        console.error('❌ FTP-Fehler:', error.message);
        process.exit(1);
    } finally {
        client.close();
    }
}

/**
 * Hauptfunktion
 */
async function main() {
    console.log('');
    console.log('╔═══════════════════════════════════════════╗');
    console.log('║   streameee APK Update Deployment         ║');
    console.log('╚═══════════════════════════════════════════╝');
    console.log('');

    // Prüfe FTP-Konfiguration
    if (!FTP_CONFIG.host || !FTP_CONFIG.user || !FTP_CONFIG.password) {
        console.error('❌ FTP-Konfiguration fehlt!');
        console.error('   Bitte .env.ftp Datei erstellen (siehe .env.ftp.example)');
        process.exit(1);
    }

    // Optional: APK bauen
    if (shouldBuild) {
        buildApk();
    }

    // Prüfe ob APK existiert
    const apkPath = path.join(__dirname, APK_SOURCE_PATH);
    if (!fs.existsSync(apkPath)) {
        console.error('❌ APK nicht gefunden:', apkPath);
        console.error('   Bitte zuerst bauen: node deploy-apk.js --build');
        process.exit(1);
    }

    // Version lesen
    const { version, versionCode } = getVersionFromPubspec();
    console.log(`📌 Version: ${version} (Code: ${versionCode})`);

    // Release Notes
    let notes = releaseNotes;
    if (!notes) {
        // Versuche aus CHANGELOG zu lesen oder Standard verwenden
        notes = `- Version ${version}`;
    }
    console.log(`📝 Release Notes: ${notes}`);

    if (forceUpdate) {
        console.log('⚠️  Force Update aktiviert!');
    }

    // Manifest erstellen
    const manifestPath = createManifest(version, versionCode, notes);
    console.log('✅ manifest.json erstellt');

    // APK-Größe anzeigen
    const stats = fs.statSync(apkPath);
    const sizeMB = (stats.size / (1024 * 1024)).toFixed(2);
    console.log(`📦 APK-Größe: ${sizeMB} MB`);

    console.log('');

    // Hochladen
    await uploadToFtp(apkPath, manifestPath, version);

    // Lokale manifest.json aufräumen
    fs.unlinkSync(manifestPath);
}

main().catch(error => {
    console.error('❌ Unerwarteter Fehler:', error);
    process.exit(1);
});
