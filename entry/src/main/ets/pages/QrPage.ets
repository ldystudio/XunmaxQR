@Component
export struct QrPage {
  @Prop qrCode: string = '';
  @Prop qrMessage: string = '';
  @Prop isLoggedIn: boolean = false;
  @Prop isLoading: boolean = false;
  onRefresh: () => void = () => {};

  build() {
    Column() {
      Blank().layoutWeight(1)

      Column({ space: 22 }) {
        Stack() {
          Column() {
          }
          .width(286)
          .height(286)
          .borderRadius(34)
          .backgroundColor($r('sys.color.comp_background_list_card'))
          .shadow({
            radius: 26,
            color: $r('sys.color.ohos_id_shadow_default_lg'),
            offsetX: 0,
            offsetY: 10
          })

          if (this.qrCode.length > 0) {
            QRCode(this.qrCode)
              .width(240)
              .height(240)
              .color(Color.Black)
              .backgroundColor(Color.White)
              .borderRadius(20)
          } else {
            Column({ space: 10 }) {
              Text('门禁二维码')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#172018')
              Text(this.isLoggedIn ? '点击下方按钮获取' : '请先登录')
                .fontSize(14)
                .fontColor('#7C8178')
            }
          }
        }
        .width('100%')
        .height(300)
        .alignContent(Alignment.Center)

        Text(this.qrMessage)
          .fontSize(14)
          .fontColor('#667061')
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .copyOption(CopyOptions.LocalDevice)

        Button(this.isLoading ? '刷新中...' : '刷新二维码')
          .width(188)
          .height(50)
          .type(ButtonType.Capsule)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor('#172018')
          .enabled(!this.isLoading && this.isLoggedIn)
          .onClick(() => {
            this.onRefresh();
          })
      }

      Blank().layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}
