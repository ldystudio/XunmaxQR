@Component
export struct MyPage {
  @Prop isLoggedIn: boolean = false;
  @Prop isLoading: boolean = false;
  @Prop phone: string = '';
  @Prop pictureCode: string = '';
  @Prop smsCode: string = '';
  @Prop pictureImage: string = '';
  @Prop userName: string = '';
  @Prop userPhone: string = '';
  @Prop userAvatar: string = '';
  @Prop qrCredentialText: string = '';
  onPhoneChange: (value: string) => void = () => {};
  onPictureCodeChange: (value: string) => void = () => {};
  onSmsCodeChange: (value: string) => void = () => {};
  onGetPictureCode: () => void = () => {};
  onVerifyPictureAndSendSms: () => void = () => {};
  onLogin: () => void = () => {};
  onOpenQr: () => void = () => {};
  onLogout: () => void = () => {};

  build() {
    Scroll() {
      Column({ space: 16 }) {
        if (this.isLoggedIn) {
          this.buildProfileCard()
          this.buildCredentialCard()
        } else {
          this.buildLoginCard()
        }
      }
      .width('100%')
      .padding({
        left: 20,
        right: 20,
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildProfileCard() {
    Column({ space: 18 }) {
      Row({ space: 14 }) {
        if (this.userAvatar.length > 0) {
          Image(this.userAvatar)
            .width(58)
            .height(58)
            .borderRadius(18)
            .objectFit(ImageFit.Cover)
        } else {
          Text('我')
            .width(58)
            .height(58)
            .borderRadius(18)
            .backgroundColor('#172018')
            .fontColor('#FFFFFF')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .textAlign(TextAlign.Center)
        }

        Column({ space: 5 }) {
          Text(this.userName.length > 0 ? this.userName : '讯美用户')
            .fontSize(21)
            .fontWeight(FontWeight.Bold)
            .fontColor('#172018')
            .width('100%')
          Text(this.userPhone.length > 0 ? this.userPhone : this.phone)
            .fontSize(14)
            .fontColor('#667061')
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Button('查看二维码')
        .width('100%')
        .height(48)
        .type(ButtonType.Capsule)
        .onClick(() => {
          this.onOpenQr();
        })

      Button('退出登录')
        .width('100%')
        .height(48)
        .type(ButtonType.Capsule)
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor($r('sys.color.hms_actionbar_nonprimary_button_color'))
        .onClick(() => {
          this.onLogout();
        })
    }
    .width('100%')
    .padding(18)
    .borderRadius(30)
    .backgroundColor($r('sys.color.comp_background_list_card'))
  }

  @Builder
  buildCredentialCard() {
    Column({ space: 12 }) {
      Text('二维码请求凭证')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#172018')
        .width('100%')

      Text('长按可复制，用于核对请求二维码接口的认证信息')
        .fontSize(13)
        .fontColor('#667061')
        .width('100%')

      Text(this.qrCredentialText)
        .width('100%')
        .padding(12)
        .borderRadius(16)
        .backgroundColor('#F3EFE5')
        .fontSize(11)
        .fontColor('#172018')
        .copyOption(CopyOptions.LocalDevice)
    }
    .width('100%')
    .padding(18)
    .borderRadius(30)
    .backgroundColor($r('sys.color.comp_background_list_card'))
  }

  @Builder
  buildLoginCard() {
    Column({ space: 14 }) {
      Text('手机号登录')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#172018')
        .width('100%')

      TextInput({ placeholder: '手机号', text: this.phone })
        .type(InputType.PhoneNumber)
        .height(50)
        .borderRadius(18)
        .backgroundColor('#F3EFE5')
        .placeholderColor('#7C8178')
        .fontColor('#172018')
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.onPhoneChange(value);
        })

      Button('1. 获取图形验证码')
        .width('100%')
        .height(46)
        .type(ButtonType.Capsule)
        .fontColor('#FFFFFF')
        .backgroundColor('#172018')
        .enabled(!this.isLoading)
        .onClick(() => {
          this.onGetPictureCode();
        })

      if (this.pictureImage.length > 0) {
        Row({ space: 10 }) {
          Image(this.pictureImage)
            .width(142)
            .height(48)
            .objectFit(ImageFit.Contain)
            .borderRadius(16)
            .backgroundColor('#F3EFE5')

          TextInput({ placeholder: '图形验证码', text: this.pictureCode })
            .layoutWeight(1)
            .height(48)
            .borderRadius(16)
            .backgroundColor('#F3EFE5')
            .placeholderColor('#7C8178')
            .fontColor('#172018')
            .padding({ left: 14, right: 14 })
            .onChange((value: string) => {
              this.onPictureCodeChange(value.toUpperCase());
            })
        }
        .width('100%')
      }

      Button('2. 校验图形码并发短信')
        .width('100%')
        .height(46)
        .type(ButtonType.Capsule)
        .fontColor('#172018')
        .backgroundColor('#D9E8D2')
        .enabled(!this.isLoading)
        .onClick(() => {
          this.onVerifyPictureAndSendSms();
        })

      TextInput({ placeholder: '短信验证码', text: this.smsCode })
        .type(InputType.Number)
        .height(50)
        .borderRadius(18)
        .backgroundColor('#F3EFE5')
        .placeholderColor('#7C8178')
        .fontColor('#172018')
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.onSmsCodeChange(value);
        })

      Button('3. 登录')
        .width('100%')
        .height(50)
        .type(ButtonType.Capsule)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor('#172018')
        .enabled(!this.isLoading)
        .onClick(() => {
          this.onLogin();
        })
    }
    .width('100%')
    .padding(20)
    .borderRadius(30)
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .shadow({
      radius: 22,
      color: $r('sys.color.ohos_id_shadow_default_md'),
      offsetX: 0,
      offsetY: 8
    })
  }
}
