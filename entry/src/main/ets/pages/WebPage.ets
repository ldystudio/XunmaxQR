import { webview } from '@kit.ArkWeb';

const WEB_URL = 'https://38.55.194.242:3000/';

@Component
export struct WebPage {
  @Prop bottomRectHeight: number = 20;
  private webController: webview.WebviewController = new webview.WebviewController();

  build() {
    Column() {
      Web({ src: WEB_URL, controller: this.webController })
        .width('100%')
        .layoutWeight(1)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onSslErrorEvent((event: SslErrorEvent) => {
          event.handler.handleConfirm();
        })

      Blank()
        .height(this.bottomRectHeight + 30)
    }
    .width('100%')
    .height('100%')
  }
}
