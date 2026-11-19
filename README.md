# ليل — Layl

مشغّل IPTV عربي بواجهة داكنة مستوحاة من السينما، مبني بـ SwiftUI على iOS 26 ويستخدم لغة التصميم Liquid Glass.

Layl is an Arabic, right-to-left IPTV player with a dark cinematic interface. It is a native SwiftUI app for iOS 26 and uses Liquid Glass (`glassEffect`, `GlassEffectContainer`, glass button styles, and the floating tab bar).

## المتطلبات / Requirements

- Mac مع Xcode 26 أو أحدث (iOS 26 SDK)
- iPhone أو iPad، أو محاكي iOS 26
- هدف النشر: iOS 26.0

Xcode 26 or later, with the iOS 26 SDK. Deployment target is iOS 26.0. A simulator or an iPhone/iPad running iOS 26 is required. Liquid Glass APIs are not available on earlier systems.

## فتح المشروع وبناؤه / Open, build, and run

1. افتح `Layl.xcodeproj` في Xcode.
2. اختر مخطط **Layl**.
3. من Signing & Capabilities اختر فريق التوقيع (Development Team). للمحاكي قد يكفي التوقيع التلقائي.
4. اختر محاكياً أو جهازاً بنظام iOS 26.
5. اضغط Run.

```bash
open Layl.xcodeproj
xcodebuild -scheme Layl -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

اسم المحاكي يختلف حسب Xcode. إن فشل التوقيع، حدّد فريقاً في إعدادات الهدف Layl.

Open `Layl.xcodeproj`, select the Layl scheme, pick your signing team, then run on an iOS 26 simulator or device. The example `xcodebuild` destination name depends on the simulators installed with your Xcode.

الاختبارات (تحليل القوائم وXMLTV وXtream والمحتوى التجريبي):

```bash
xcodebuild -scheme Layl -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## الواجهة / Screens

- **الرئيسية**: شريط علوي (هلال ليل، AirPlay، التنزيلات، الإشعارات)، كبسولات زجاجية (مسلسلات، جديد ورائج، أفلام، التصنيفات)، بطاقة بطل «سينتل»، صف «حصرياً على ليل»، ثم صفوف للأعمال والمتابعة والبث.
- **التفاصيل**: صورة عريضة، إغلاق زجاجي، السنة وشارة PG وHD، تشغيل، تنزيل الموسم، التقييم (ليس لي / أعجبني / أحببت هذا!!)، الحلقات والمزيد مثل هذا.
- **مقاطع**: موجز عمودي بتشغيل AVPlayer وأزرار زجاجية.
- **بحث**: حقل زجاجي، نطاقات، ونتائج.
- **حسابي**: ملفات (ليل، العائلة، أطفال)، قائمتي، التنزيلات، الإعدادات.
- **بث مباشر**: تصنيفات ودليل برامج (الآن / التالي).
- **المشغّل**: شاشة كاملة بـ AVPlayer، تشغيل/إيقاف، ±10 ثوانٍ، شريط تقدم، ترجمة، صوت، AirPlay، وصورة داخل صورة.
- **إضافة قائمة**: M3U/M3U8 بالرابط أو بملف، أو Xtream Codes، مع مقدمة أولى.

The whole interface is Arabic and forced right-to-left. Layout adapts from iPhone SE through Pro Max and iPad (sidebar tab style on iPad, two-pane live guide on regular width). Text uses scaling fonts and `ViewThatFits` where a row would overflow at large Dynamic Type sizes. Appearance is locked to Dark.

## إضافة قائمة تشغيل / Add a playlist

من حسابي ← إضافة قائمة تشغيل، أو من المقدمة.

### M3U / M3U8

ألصق رابط الملف، واختيارياً رابط XMLTV. يمكن أيضاً استيراد ملف `.m3u` أو تحميل **القائمة النموذجية** المضمّنة، وهي تستخدم بثاً مفتوحاً فقط.

```text
#EXTM3U
#EXTINF:-1 tvg-id="news" tvg-logo="https://example.com/logo.png" group-title="أخبار",القناة
https://example.com/live/stream.m3u8
```

التحليل يفرز البث المباشر، والأفلام (امتداد فيديو أو مسار `/movie/`)، والمسلسلات (`S01E02` أو مسار `/series/` أو مجموعة «مسلسلات»).

### Xtream Codes

أدخل عنوان الخادم (مع المنفذ، مثل `http://host:8080`)، واسم المستخدم، وكلمة المرور. التطبيق يستدعي `player_api.php` ويجلب التصنيفات والبث والأفلام والمسلسلات. الحلقات تُجلب عند فتح المسلسل. دليل مختصر يُطلب لأول القنوات. كلمة المرور تُحفظ في سلسلة المفاتيح.

لا تُرفق أي قوائم أو بث محمي الحقوق. أنت مسؤول عن القوائم التي تضيفها.

## المحتوى التجريبي / Demo content

الشاشة الرئيسية ممتلئة قبل إضافة أي قائمة. العناوين والصور أصلية داخل التطبيق. ملفات التشغيل التجريبية فقط:

| العمل | المصدر | الرخصة |
| --- | --- | --- |
| سينتل | Blender Foundation | CC BY 3.0 |
| الأرنب الكبير / Big Buck Bunny | Blender Foundation | CC BY 3.0 |
| دموع الفولاذ / Tears of Steel | Blender Foundation | CC BY 3.0 |
| حلم الفيلة / Elephants Dream | Blender Foundation | CC BY |
| أمثلة HLS من Apple (`bipbop`) | Apple Developer Streaming examples | نماذج مطورين |
| `test-streams.mux.dev` | Mux test stream (Big Buck Bunny) | اختبار |

يمكن إخفاء المحتوى التجريبي من الإعدادات.

## ما يُحفظ / Persistence

SwiftData يحفظ القوائم، المفضلة (قائمتي)، تقدم المشاهدة، التفاعلات، الملفات الشخصية، وسجل التنزيل. كتالوج كل قائمة يُخزَّن كملف JSON في Application Support حتى يعمل بدون شبكة بعد أول مزامنة. التنزيل التقدمي (MP4) عبر `URLSession`، وبث HLS عبر `AVAssetDownloadURLSession`.

## البنية / Architecture

MVVM. `AppModel` هو حالة التطبيق. الشاشات لها نماذج خفيفة (`HomeModel`, `DetailModel`, `SearchModel`, `PlayerModel`). التحليل والشبكة في `Services` بدون SwiftUI. لا تبعيات خارجية.

## ملاحظات واجهة برمجة التطبيقات / API caveats

هذه البيئة لا تحتوي على Xcode أو محاكي iOS، لذلك **لم يُبنَ المشروع هنا**. الواجهات كُتبت وفق توثيق iOS 26 (WWDC25 ووثائق Apple):

- `glassEffect(_:in:)` و`Glass.regular.tint(_:).interactive()` و`GlassEffectContainer` و`.buttonStyle(.glass)` و`.buttonStyle(.glassProminent)` و`.buttonStyle(.glass(_:))`.
- `Tab` مع `tabBarMinimizeBehavior(.onScrollDown)` و`tabViewStyle(.sidebarAdaptable)`. شريط التبويب العائم يأتي من النظام؛ صورة الملف في التبويب قد تتحول إلى قالب أحادي اللون حسب رسم شريط iOS 26.
- تنزيل HLS يستخدم `AVAssetDownloadConfiguration` و`makeAssetDownloadTask(downloadConfiguration:)`. الدالة الأقدم `makeAssetDownloadTask(asset:assetTitle:assetArtworkData:options:)` مهملة. إن تغيّر توقيع مندوب `willDownloadTo` في SDK نهائي، قد يتأخر تحديث شريط تقدم HLS بينما يبقى تنزيل MP4 على واجهة `URLSessionDownloadDelegate` الثابتة.
- الصورة داخل الصورة تحتاج نمط الخلفية `audio` (مضبوط في Info.plist) وجلسة `AVAudioSession` للتشغيل. إغلاق شاشة المشغّل يوقف الصورة داخل الصورة لأن المشغّل يُفك مع الشاشة.
- كثير من خوادم IPTV تستخدم HTTP. `NSAllowsArbitraryLoads` مفعّل لهذا السبب، مع وصف استخدام الشبكة المحلية.
- تحليل M3U وXtream اجتهادي. اللوحات تختلف في أنواع JSON (رقم أو نص) والحلقات قد تأتي لاحقاً عند فتح المسلسل.
- ملفات XMLTV الكبيرة تُقصّ بعد حوالي 8 ميغابايت و4000 برنامج حتى لا يمتلئ الذاكرة.
- لغة الواجهة عربية واتجاهها من اليمين لليسار حتى لو كانت لغة الجهاز غير ذلك. بعض أزرار النظام قد تبقى بلغة الجهاز في أول إقلاع.

This environment has no Xcode, so the project was not compiled here. Confirm the build on Xcode 26 before shipping. Select a signing team for a device build.
