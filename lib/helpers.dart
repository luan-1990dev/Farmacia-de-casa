import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

Future<void> abrirLojaDeApps() async {
  // O seu ID que aparece no Manifest: com.luandevfullstack.crtl_02
  const String appIdAndroid = "com.luandevfullstack.crtl_02";
  const String appIdiOS = "123456789";

  Uri url;

  if (Platform.isAndroid) {
    url = Uri.parse("market://details?id=$appIdAndroid");
  } else if (Platform.isIOS) {
    url = Uri.parse("https://apps.apple.com/app/id$appIdiOS");
  } else {
    return;
  }

  try {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (Platform.isAndroid) {
        url = Uri.parse("https://play.google.com/store/apps/details?id=$appIdAndroid");
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  } catch (e) {
    print("Erro ao abrir a loja: $e");
  }
}