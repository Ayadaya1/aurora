#include <webview_flutter_aurora/webview_flutter_aurora_plugin.h>
#include "generated_plugin_registrant.h"

int main(int argc, char *argv[]) {
  WebviewFlutterAuroraPluginStartProcess(argc, argv, WEBVIEW_SUBPROCESS_LAUNCHER_INSTALL_PATH);
  WebviewFlutterAuroraPluginInitQCA();
  aurora::FlutterApp app(argc, argv);
  return app.exec();
}
