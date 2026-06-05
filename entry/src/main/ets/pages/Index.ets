import { preferences } from '@kit.ArkData';
import { hdsMaterial, HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { UserInfo } from '../model/XmTypes';
import { AuthSnapshot, xmApi } from '../service/XmApi';
import { sha256Hex } from '../util/Sha256';

const AUTH_STORE = 'xunmax_auth_store';
const KEY_TOKEN = 'token';
const KEY_COOKIE = 'cookie';
const KEY_AUTH_MODE = 'authMode';
const KEY_PHONE = 'phone';
const KEY_USER_NAME = 'userName';
const KEY_USER_PHONE = 'userPhone';
const KEY_USER_AVATAR = 'userAvatar';
const QR_TAB = 0;
const MY_TAB = 1;

@Entry
@Component
struct Index {
  @State currentTab: number = QR_TAB;
  @State phone: string = '';
  @State pictureCode: string = '';
  @State smsCode: string = '';
  @State pictureKey: string = '';
  @State pictureImage: string = '';
  @State qrCode: string = '';
  @State userName: string = '';
  @State userPhone: string = '';
  @State userAvatar: string = '';
  @State isLoggedIn: boolean = false;
  @State isLoading: boolean = false;
  @State statusMessage: string = '请登录后使用门禁二维码';
  @State qrMessage: string = '登录后可获取门禁二维码';
  @State pageOpacity: number = 0;
  @State pageOffset: number = 16;
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 20;
  private tabsController: HdsTabsController = new HdsTabsController();

  aboutToAppear(): void {
    this.currentTab = QR_TAB;
    this.restoreSession();
    if (this.isLoggedIn) {
      this.getQrCode();
    } else {
      this.switchToMy();
    }
    this.getUIContext().animateTo({ duration: 420, curve: Curve.EaseOut }, () => {
      this.pageOpacity = 1;
      this.pageOffset = 0;
    });
  }

  async getPictureCode(): Promise<void> {
    if (!this.ensurePhone()) {
      return;
    }
    this.isLoading = true;
    this.statusMessage = '正在获取图形验证码...';
    const result = await xmApi.getPictureCode(this.phone.trim());
    this.isLoading = false;

    if (result.error) {
      this.statusMessage = `图形验证码失败：${result.error.msg}`;
      return;
    }
    this.pictureKey = result.data?.key || '';
    this.pictureImage = `data:image/jpg;base64,${result.data?.pictureCode || ''}`;
    this.pictureCode = '';
    this.statusMessage = '图形验证码已获取';
  }

  async verifyPictureAndSendSms(): Promise<void> {
    if (!this.ensurePhone() || !this.ensureText(this.pictureCode, '请输入图形验证码')) {
      return;
    }
    if (!this.ensureText(this.pictureKey, '请先获取图形验证码')) {
      return;
    }

    this.isLoading = true;
    this.statusMessage = '正在校验图形验证码...';
    const verifyResult =
      await xmApi.verifyPictureCode(this.phone.trim(), this.pictureCode.trim().toUpperCase(), this.pictureKey);
    if (verifyResult.error) {
      this.isLoading = false;
      this.statusMessage = `图形验证码错误：${verifyResult.error.msg}`;
      return;
    }

    this.statusMessage = '图形码通过，正在发送短信...';
    const sendResult = await xmApi.sendCodeForLogonNew(this.phone.trim());
    this.isLoading = false;

    if (sendResult.error) {
      this.statusMessage = `短信发送失败：${sendResult.error.msg}`;
      return;
    }
    this.statusMessage = '短信已发送，请输入验证码登录';
  }

  async login(): Promise<void> {
    if (!this.ensurePhone() || !this.ensureText(this.smsCode, '请输入短信验证码')) {
      return;
    }

    this.isLoading = true;
    const verificationCode = sha256Hex(this.smsCode.trim());
    if (verificationCode.length === 0) {
      this.isLoading = false;
      this.statusMessage = '短信码加密失败';
      return;
    }

    this.statusMessage = '正在校验短信验证码...';
    const verifyResult = await xmApi.verifyCode(this.phone.trim(), verificationCode);
    if (verifyResult.error) {
      this.isLoading = false;
      this.statusMessage = `短信码校验失败：${verifyResult.error.msg}`;
      return;
    }

    this.statusMessage = '正在登录...';
    const loginResult = await xmApi.verifyAndLogonByCode(this.phone.trim(), verificationCode);
    if (loginResult.error) {
      this.isLoading = false;
      this.statusMessage = `登录失败：${loginResult.error.msg}`;
      return;
    }

    this.isLoggedIn = true;
    this.userPhone = this.phone.trim();
    this.saveSession();
    this.statusMessage = '登录成功，正在同步用户信息...';

    const userResult = await xmApi.getUserInfo();
    this.isLoading = false;
    if (!userResult.error) {
      this.setUser(userResult.data);
    }
    this.saveSession();
    this.statusMessage = '已登录，凭证已保存';
    this.qrMessage = '可切到二维码页获取门禁码';
  }

  async getQrCode(): Promise<void> {
    if (!this.isLoggedIn) {
      this.currentTab = MY_TAB;
      this.statusMessage = '请先登录，再查看二维码';
      return;
    }

    this.isLoading = true;
    this.qrMessage = '正在刷新二维码...';

    const result = await xmApi.listDoorAccessQRKeyNew();
    this.isLoading = false;

    if (result.error) {
      this.qrMessage = `二维码获取失败：${result.error.msg}`;
      return;
    }
    const topKey = result.data?.topKeys?.[0];
    if (!topKey?.webQRCode) {
      this.qrMessage = '接口未返回二维码内容';
      return;
    }
    this.qrCode = topKey.webQRCode;
    this.qrMessage = '二维码已刷新';
  }

  logout(): void {
    xmApi.clearAuth();
    this.clearSession();
    this.isLoggedIn = false;
    this.qrCode = '';
    this.smsCode = '';
    this.pictureCode = '';
    this.pictureKey = '';
    this.pictureImage = '';
    this.userName = '';
    this.userPhone = '';
    this.userAvatar = '';
    this.currentTab = MY_TAB;
    this.statusMessage = '已退出登录';
    this.qrMessage = '登录后可获取门禁二维码';
  }

  build() {
    Stack() {
      this.buildBackground()

      Column() {
        this.buildHeader()
        HdsTabs({ barPosition: BarPosition.End, index: this.currentTab, controller: this.tabsController }) {
          TabContent() {
            this.buildQrPage()
          }
          .tabBar(this.createBottomTab(this.createSymbol('qrcode'), '二维码'))

          TabContent() {
            this.buildMyPage()
          }
          .tabBar(this.createBottomTab(this.createSymbol('person'), '我的'))
        }
        .layoutWeight(1)
        .barPosition(BarPosition.End)
        .barOverlap(true)
        .barFloatingStyle({
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
          },
          barOpacity: 0.9
        })
        .animationDuration(300)
        .onChange((index: number) => {
          this.handleTabChange(index);
        })
      }
      .width('100%')
      .height('100%')
      .opacity(this.pageOpacity)
      .translate({ y: this.pageOffset })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f6')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  buildBackground() {
    Stack() {
      Column() {
      }
      .width(210)
      .height(210)
      .borderRadius(105)
      .backgroundColor('#D9E8D2')
      .opacity(0.68)
      .position({ x: -76, y: -42 })

      Column() {
      }
      .width(180)
      .height(180)
      .borderRadius(90)
      .backgroundColor('#F2C992')
      .opacity(0.42)
      .position({ x: 250, y: 122 })

      Column() {
      }
      .width(260)
      .height(260)
      .borderRadius(130)
      .backgroundColor('#DCE8F6')
      .opacity(0.72)
      .position({ x: 118, y: 610 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildHeader() {
    Column({ space: 8 }) {
      Text('讯美门禁')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor('#172018')
        .width('100%')

      Text(this.isLoggedIn ? '凭证已保存，退出登录前一直保留' : '先登录，再使用二维码开门')
        .fontSize(14)
        .fontColor('#667061')
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({
      left: 24,
      right: 24,
      top: 20
    })
  }

  @Builder
  buildQrPage() {
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

        Button(this.isLoading ? '刷新中...' : '刷新二维码')
          .width(188)
          .height(50)
          .type(ButtonType.Capsule)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor('#172018')
          .enabled(!this.isLoading && this.isLoggedIn)
          .onClick(() => this.getQrCode())
      }

      Blank().layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildMyPage() {
    Column({ space: 16 }) {
      if (this.isLoggedIn) {
        this.buildProfileCard()
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
          this.switchToQr();
          if (this.qrCode.length === 0) {
            this.getQrCode();
          }
        })

      Button('退出登录')
        .width('100%')
        .height(48)
        .type(ButtonType.Capsule)
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor($r('sys.color.hms_actionbar_nonprimary_button_color'))
        .onClick(() => {
          this.logout();
        })
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
          this.phone = value;
        })

      Button('1. 获取图形验证码')
        .width('100%')
        .height(46)
        .type(ButtonType.Capsule)
        .fontColor('#FFFFFF')
        .backgroundColor('#172018')
        .enabled(!this.isLoading)
        .onClick(() => {
          this.getPictureCode();
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
              this.pictureCode = value.toUpperCase();
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
          this.verifyPictureAndSendSms();
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
          this.smsCode = value;
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
          this.login();
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

  private restoreSession(): void {
    try {
      const prefs = this.getPreferences();
      const snapshot: AuthSnapshot = {
        token: this.readString(prefs, KEY_TOKEN),
        cookieHeader: this.readString(prefs, KEY_COOKIE),
        authMode: this.readString(prefs, KEY_AUTH_MODE)
      };
      xmApi.restoreAuth(snapshot);
      this.phone = this.readString(prefs, KEY_PHONE);
      this.userName = this.readString(prefs, KEY_USER_NAME);
      this.userPhone = this.readString(prefs, KEY_USER_PHONE);
      this.userAvatar = this.readString(prefs, KEY_USER_AVATAR);
      this.isLoggedIn = xmApi.hasCredentials();
      this.statusMessage = this.isLoggedIn ? '已恢复登录，可直接使用二维码' : '请登录后使用门禁二维码';
      this.qrMessage = this.isLoggedIn ? '点击刷新获取门禁二维码' : '登录后可获取门禁二维码';
    } catch (error) {
      this.statusMessage = `读取登录态失败：${this.stringifyError(error as Object)}`;
    }
  }

  private saveSession(): void {
    try {
      const prefs = this.getPreferences();
      const snapshot = xmApi.exportAuth();
      prefs.putSync(KEY_TOKEN, snapshot.token);
      prefs.putSync(KEY_COOKIE, snapshot.cookieHeader);
      prefs.putSync(KEY_AUTH_MODE, snapshot.authMode);
      prefs.putSync(KEY_PHONE, this.phone.trim());
      prefs.putSync(KEY_USER_NAME, this.userName);
      prefs.putSync(KEY_USER_PHONE, this.userPhone);
      prefs.putSync(KEY_USER_AVATAR, this.userAvatar);
      prefs.flush();
    } catch (error) {
      this.statusMessage = `保存登录态失败：${this.stringifyError(error as Object)}`;
    }
  }

  private clearSession(): void {
    try {
      const prefs = this.getPreferences();
      const keys: Array<string> =
        [KEY_TOKEN, KEY_COOKIE, KEY_AUTH_MODE, KEY_PHONE, KEY_USER_NAME, KEY_USER_PHONE, KEY_USER_AVATAR];
      for (let index = 0; index < keys.length; index += 1) {
        if (prefs.hasSync(keys[index])) {
          prefs.deleteSync(keys[index]);
        }
      }
      prefs.flush();
    } catch (error) {
      this.statusMessage = `清理登录态失败：${this.stringifyError(error as Object)}`;
    }
  }

  private getPreferences(): preferences.Preferences {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      throw new Error('Host context unavailable');
    }
    return preferences.getPreferencesSync(context, { name: AUTH_STORE });
  }

  private readString(prefs: preferences.Preferences, key: string): string {
    const value = prefs.getSync(key, '');
    if (typeof value === 'string') {
      return value;
    }
    return '';
  }

  private setUser(userInfo: UserInfo | null | undefined): void {
    if (!userInfo) {
      return;
    }
    this.userName = userInfo.nickName;
    this.userAvatar = userInfo.avatarUrl;
    this.userPhone = userInfo.phones.length > 0 ? userInfo.phones[0] : this.phone.trim();
  }

  private ensurePhone(): boolean {
    return this.ensureText(this.phone, '请输入手机号');
  }

  private ensureText(value: string, message: string): boolean {
    if (value.trim().length > 0) {
      return true;
    }
    this.statusMessage = message;
    return false;
  }

  private stringifyError(error: Object): string {
    try {
      return JSON.stringify(error);
    } catch (_) {
      return `${error}`;
    }
  }

  private handleTabChange(index: number): void {
    if (index === QR_TAB && !this.isLoggedIn) {
      this.switchToMy();
      this.statusMessage = '请先登录，再查看二维码';
      return;
    }
    this.currentTab = index;
    if (index === QR_TAB && this.qrCode.length === 0) {
      this.getQrCode();
    }
  }

  private switchToMy(): void {
    this.currentTab = MY_TAB;
    this.tabsController.changeIndex(MY_TAB);
  }

  private switchToQr(): void {
    if (!this.isLoggedIn) {
      this.switchToMy();
      this.statusMessage = '请先登录，再查看二维码';
      return;
    }
    this.currentTab = QR_TAB;
    this.tabsController.changeIndex(QR_TAB);
  }

  private createSymbol(name: 'qrcode' | 'person'): TabBarSymbol {
    const normal = new SymbolGlyphModifier($r(`sys.symbol.${name}`))
      .fontColor(['#6D776A'])
      .fontSize(24);
    const selected = new SymbolGlyphModifier($r(`sys.symbol.${name}`))
      .fontColor(['#172018'])
      .fontSize(24);
    return { normal, selected };
  }

  private createBottomTab(icon: TabBarSymbol, title: string): BottomTabBarStyle {
    return BottomTabBarStyle.of(icon, title)
      .labelStyle({ selectedColor: '#172018', unselectedColor: '#6D776A' })
      .iconStyle({ selectedColor: '#172018', unselectedColor: '#6D776A' })
      .layoutMode(LayoutMode.VERTICAL)
  }
}
