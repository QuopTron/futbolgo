# 🚀 Instrucciones para Crear el Release Automáticamente

He creado un script que puede crear el release en GitHub y subir el APK por ti.

## 🔑 Paso 1: Obtener un Token de GitHub

1. Ve a: **https://github.com/settings/tokens**
2. Click en **"Generate new token (classic)"**
3. En description escribe: `FutbolGO Release`
4. En **Expiration**: selecciona `30 days` (o lo que prefieras)
5. Marca el checkbox: **`repo`** (parahaccess total a tus repositorios)
6. Click en **"Generate token"**
7. **COPIA EL TOKEN** (solo se muestra una vez)

## 🎮 Paso 2: Ejecutar el Script

Abre PowerShell y ejecuta:

```powershell
cd "E:\Pablo\proyectos\futbolgo\flutter_app"
.\create_release.ps1
```

## 📝 Paso 3: Ingresa el Token

El script te pedirá que ingreses el token de GitHub. Pega el token que copiaste.

```
Enter your GitHub personal access token: [pega tu token aquí]
```

## ✅ El Script Hará:

1. ✅ Creará el release v1.1.0 en GitHub
2. ✅ Subirá el APK `futbolgo.apk`
3. ✅ Agregará todas las notas de lanzamiento
4. ✅ Te dará los enlaces de descarga

## 🔗 Resultados

Al finalizar, obtendrás:

- **URL de descarga del APK**: `https://github.com/QuopTron/futbolgo/releases/download/v1.1.0/futbolgo.apk`
- **URL del release**: `https://github.com/QuopTron/futbolgo/releases/tag/v1.1.0`

## 🎉 Listo!

Los usuarios podrán descargar el APK directamente desde GitHub y la app detectarán automáticamente las actualizaciones.

---
## ⚠️ Nota Importante

El token que generas es para **acceso a tu cuenta de GitHub**. Guárdalo de forma segura. Puedes revocarlo en cualquier momento desde: https://github.com/settings/tokens

## 🆘 Si Tienes Problemas

Si el script te da algún error, copia el mensaje de error y te ayudaré a solucionarlo.

¡El script hace todo el trabajo pesado por ti! 🚀
