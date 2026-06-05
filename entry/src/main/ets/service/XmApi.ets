import { http } from '@kit.NetworkKit';
import {
  BackendResponse,
  DoorAccessQrResponse,
  LoginResponse,
  PictureCodeResponse,
  RequestResult,
  SendCodeForLogonNewResponse,
  UserInfo,
  VerifyCodeResponse
} from '../model/XmTypes';

const BASE_URL = 'https://xunmei.zuolin.com';
const DEFAULT_REFERER = `${BASE_URL}/`;
const QR_REFERER = `${BASE_URL}/entrance-guard/build/index.html`;
const SUCCESS_CODES: Array<number> = [200, 201, 202, 204];
const REQUEST_TIMEOUT = 10000;
const FORM_BOUNDARY = '----XunmaxQrHarmonyBoundary';

type AuthMode = 'none' | 'cookie' | 'authorization' | 'bearer' | 'cookieAndAuthorization';

interface FormBody {
  namespaceId?: number;
  regionCode?: number;
  identifierToken?: string;
  pictureCode?: string;
  key?: string;
  phone?: string;
  verificationCode?: string;
}

interface HeaderBody {
  'Content-Type'?: string;
  'Origin': string;
  'Referer': string;
  'Cookie'?: string;
  'Authorization'?: string;
}

interface CookiePair {
  name: string;
  value: string;
}

export interface AuthSnapshot {
  token: string;
  cookieHeader: string;
  authMode: string;
}

export class XmApi {
  private token: string = '';
  private cookies: Array<CookiePair> = [];
  private authMode: AuthMode = 'cookie';

  async getPictureCode(phone: string): Promise<RequestResult<PictureCodeResponse>> {
    return this.postForm<PictureCodeResponse>('/user/getPictureCode', {
      namespaceId: 999920,
      regionCode: 86,
      identifierToken: phone
    });
  }

  async verifyPictureCode(phone: string, pictureCode: string, key: string): Promise<RequestResult<null>> {
    return this.postForm<null>('/user/verifyPictureCode', {
      namespaceId: 999920,
      regionCode: 86,
      identifierToken: phone,
      pictureCode,
      key
    });
  }

  async sendCodeForLogonNew(phone: string): Promise<RequestResult<SendCodeForLogonNewResponse>> {
    return this.postForm<SendCodeForLogonNewResponse>('/user/sendCodeForLogonNew', {
      namespaceId: 999920,
      regionCode: 86,
      phone
    });
  }

  async verifyCode(phone: string, verificationCode: string): Promise<RequestResult<VerifyCodeResponse>> {
    return this.postForm<VerifyCodeResponse>('/user/verifyCode', {
      namespaceId: 999920,
      regionCode: 86,
      phone,
      verificationCode
    });
  }

  async verifyAndLogonByCode(phone: string, verificationCode: string): Promise<RequestResult<LoginResponse>> {
    const result = await this.postForm<LoginResponse>('/user/verifyAndLogonByCode', {
      namespaceId: 999920,
      regionCode: 86,
      phone,
      verificationCode
    }, 'captureLoginCookie');
    if (result.data?.loginToken) {
      this.token = result.data.loginToken;
    }
    return result;
  }

  async getUserInfo(): Promise<RequestResult<UserInfo>> {
    return this.postProtectedForm<UserInfo>('/user/getUserInfo', {});
  }

  async listDoorAccessQRKeyNew(): Promise<RequestResult<DoorAccessQrResponse>> {
    return this.getProtected<DoorAccessQrResponse>('/evh/aclink/listDoorAccessQRKeyNew', QR_REFERER);
  }

  getDebugAuth(): string {
    const cookie = this.getCookieHeader();
    if (this.token.length > 0 || cookie.length > 0) {
      return `mode=${this.authMode}, token ${this.token.length}, cookie ${cookie.length}`;
    }
    return 'empty';
  }

  hasCredentials(): boolean {
    return this.token.length > 0 || this.getCookieHeader().length > 0;
  }

  exportAuth(): AuthSnapshot {
    return {
      token: this.token,
      cookieHeader: this.getCookieHeader(),
      authMode: this.authMode
    };
  }

  restoreAuth(snapshot: AuthSnapshot): void {
    this.token = snapshot.token;
    this.cookies = [];
    this.setCookieHeader(snapshot.cookieHeader);
    this.authMode = this.normalizeAuthMode(snapshot.authMode);
  }

  clearAuth(): void {
    this.token = '';
    this.cookies = [];
    this.authMode = 'cookie';
  }

  private async postProtectedForm<T>(path: string, body: FormBody): Promise<RequestResult<T>> {
    const modes = this.getCandidateAuthModes();
    let lastResult: RequestResult<T> | null = null;

    for (let index = 0; index < modes.length; index += 1) {
      const mode = modes[index];
      const result = await this.postForm<T>(path, body, 'none', mode);
      if (!result.error) {
        this.authMode = mode;
        return result;
      }
      lastResult = result;
      if (!this.isAuthError(result)) {
        return result;
      }
    }

    if (lastResult) {
      return lastResult;
    }
    return this.createNetworkError<T>(new Error('No auth mode available'));
  }

  private async getProtected<T>(path: string, referer: string): Promise<RequestResult<T>> {
    const modes = this.getCandidateAuthModes();
    let lastResult: RequestResult<T> | null = null;

    for (let index = 0; index < modes.length; index += 1) {
      const mode = modes[index];
      const result = await this.getWithMode<T>(path, referer, mode);
      if (!result.error) {
        this.authMode = mode;
        return result;
      }
      lastResult = result;
      if (!this.isAuthError(result)) {
        return result;
      }
    }

    if (lastResult) {
      return lastResult;
    }
    return this.createNetworkError<T>(new Error('No auth mode available'));
  }

  private async getWithMode<T>(path: string, referer: string, authMode: AuthMode): Promise<RequestResult<T>> {
    const request = http.createHttp();
    try {
      const response = await request.request(`${BASE_URL}${path}`, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        header: this.createHeaders('application/x-www-form-urlencoded', referer, authMode),
        connectTimeout: REQUEST_TIMEOUT,
        readTimeout: REQUEST_TIMEOUT
      });
      this.captureResponseCookies(response);
      return this.handleResponse<T>(response);
    } catch (error) {
      return this.createNetworkError<T>(error as Object);
    } finally {
      request.destroy();
    }
  }

  private async postForm<T>(
    path: string,
    body: FormBody,
    cookiePolicy: 'none' | 'captureLoginCookie' = 'none',
    authMode: AuthMode = 'cookie'
  ): Promise<RequestResult<T>> {
    const request = http.createHttp();
    try {
      const response = await request.request(`${BASE_URL}${path}`, {
        method: http.RequestMethod.POST,
        expectDataType: http.HttpDataType.STRING,
        header: this.createHeaders(`multipart/form-data; boundary=${FORM_BOUNDARY}`, DEFAULT_REFERER, authMode),
        extraData: this.toMultipartForm(body),
        connectTimeout: REQUEST_TIMEOUT,
        readTimeout: REQUEST_TIMEOUT
      });
      this.captureResponseCookies(response);
      const result = this.handleResponse<T>(response);
      if (!result.error && cookiePolicy === 'captureLoginCookie') {
        this.authMode = 'cookie';
      }
      return result;
    } catch (error) {
      return this.createNetworkError<T>(error as Object);
    } finally {
      request.destroy();
    }
  }

  private createHeaders(contentType: string | undefined, referer: string, authMode: AuthMode): HeaderBody {
    const hasContentType = contentType !== undefined && contentType.length > 0;
    const hasToken = this.token.length > 0;
    const hasCookie = this.getCookieHeader().length > 0;

    if (hasContentType) {
      return this.createTypedHeaders(contentType, referer, authMode, hasCookie, hasToken);
    }
    return this.createTypedHeadersWithoutContentType(referer, authMode, hasCookie, hasToken);
  }

  private createTypedHeaders(
    contentType: string,
    referer: string,
    authMode: AuthMode,
    hasCookie: boolean,
    hasToken: boolean
  ): HeaderBody {
    if (authMode === 'cookie' && hasCookie) {
      return { 'Content-Type': contentType, 'Origin': DEFAULT_REFERER, 'Referer': referer, 'Cookie': this.getCookieHeader() };
    }
    if (authMode === 'authorization' && hasToken) {
      return { 'Content-Type': contentType, 'Origin': DEFAULT_REFERER, 'Referer': referer, 'Authorization': this.token };
    }
    if (authMode === 'bearer' && hasToken) {
      return { 'Content-Type': contentType, 'Origin': DEFAULT_REFERER, 'Referer': referer, 'Authorization': `Bearer ${this.token}` };
    }
    if (authMode === 'cookieAndAuthorization' && hasCookie && hasToken) {
      return {
        'Content-Type': contentType,
        'Origin': DEFAULT_REFERER,
        'Referer': referer,
        'Cookie': this.getCookieHeader(),
        'Authorization': this.token
      };
    }
    return { 'Content-Type': contentType, 'Origin': DEFAULT_REFERER, 'Referer': referer };
  }

  private createTypedHeadersWithoutContentType(
    referer: string,
    authMode: AuthMode,
    hasCookie: boolean,
    hasToken: boolean
  ): HeaderBody {
    if (authMode === 'cookie' && hasCookie) {
      return { 'Origin': DEFAULT_REFERER, 'Referer': referer, 'Cookie': this.getCookieHeader() };
    }
    if (authMode === 'authorization' && hasToken) {
      return { 'Origin': DEFAULT_REFERER, 'Referer': referer, 'Authorization': this.token };
    }
    if (authMode === 'bearer' && hasToken) {
      return { 'Origin': DEFAULT_REFERER, 'Referer': referer, 'Authorization': `Bearer ${this.token}` };
    }
    if (authMode === 'cookieAndAuthorization' && hasCookie && hasToken) {
      return { 'Origin': DEFAULT_REFERER, 'Referer': referer, 'Cookie': this.getCookieHeader(), 'Authorization': this.token };
    }
    return { 'Origin': DEFAULT_REFERER, 'Referer': referer };
  }

  private toMultipartForm(body: FormBody): string {
    const list: Array<string> = [];
    this.pushMultipartItem(list, 'namespaceId', body.namespaceId);
    this.pushMultipartItem(list, 'regionCode', body.regionCode);
    this.pushMultipartItem(list, 'identifierToken', body.identifierToken);
    this.pushMultipartItem(list, 'pictureCode', body.pictureCode);
    this.pushMultipartItem(list, 'key', body.key);
    this.pushMultipartItem(list, 'phone', body.phone);
    this.pushMultipartItem(list, 'verificationCode', body.verificationCode);
    return `${list.join('')}\r\n--${FORM_BOUNDARY}--\r\n`;
  }

  private pushMultipartItem(list: Array<string>, name: string, value: string | number | undefined): void {
    if (value === undefined) {
      return;
    }
    list.push(`\r\n--${FORM_BOUNDARY}\r\nContent-Disposition: form-data; name="${name}"\r\n\r\n${value}`);
  }

  private getCandidateAuthModes(): Array<AuthMode> {
    const modes: Array<AuthMode> = [];
    if (this.getCookieHeader().length > 0) {
      modes.push('cookie');
    }
    if (this.token.length > 0) {
      modes.push('authorization');
      modes.push('bearer');
    }
    if (this.getCookieHeader().length > 0 && this.token.length > 0) {
      modes.push('cookieAndAuthorization');
    }
    return modes;
  }

  private captureResponseCookies(response: http.HttpResponse): void {
    this.captureCookieText(response.cookies);
    this.captureCookieText(JSON.stringify(response.header));
  }

  private captureCookieText(text: string): void {
    if (text.trim().length === 0) {
      return;
    }

    const normalized = text.replace(/\\r/g, '\r').replace(/\\n/g, '\n');
    const cookiePattern = /([A-Za-z0-9_.-]+)=([^;,\]\}"\\\s]+)/g;
    let match = cookiePattern.exec(normalized);
    while (match !== null) {
      const name = match[1];
      const value = match[2];
      if (this.isCookieName(name) && value.length > 0) {
        this.upsertCookie(name, value);
      }
      match = cookiePattern.exec(normalized);
    }
  }

  private isCookieName(name: string): boolean {
    const lower = name.toLowerCase();
    return lower !== 'path' && lower !== 'domain' && lower !== 'expires' && lower !== 'max-age' &&
      lower !== 'secure' && lower !== 'httponly' && lower !== 'samesite' && lower !== 'charset';
  }

  private upsertCookie(name: string, value: string): void {
    for (let index = 0; index < this.cookies.length; index += 1) {
      if (this.cookies[index].name === name) {
        this.cookies[index].value = value;
        return;
      }
    }
    this.cookies.push({ name, value });
  }

  private getCookieHeader(): string {
    const pairs: Array<string> = [];
    for (let index = 0; index < this.cookies.length; index += 1) {
      pairs.push(`${this.cookies[index].name}=${this.cookies[index].value}`);
    }
    return pairs.join('; ');
  }

  private setCookieHeader(cookieHeader: string): void {
    if (cookieHeader.trim().length === 0) {
      return;
    }
    const pairs = cookieHeader.split(';');
    for (let index = 0; index < pairs.length; index += 1) {
      const item = pairs[index].trim();
      const separatorIndex = item.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }
      const name = item.substring(0, separatorIndex);
      const value = item.substring(separatorIndex + 1);
      if (this.isCookieName(name) && value.length > 0) {
        this.upsertCookie(name, value);
      }
    }
  }

  private normalizeAuthMode(value: string): AuthMode {
    if (value === 'cookie' || value === 'authorization' || value === 'bearer' || value === 'cookieAndAuthorization') {
      return value;
    }
    return 'cookie';
  }

  private isAuthError<T>(result: RequestResult<T>): boolean {
    if (!result.error) {
      return false;
    }
    const text = `${result.error.code} ${result.error.msg} ${result.raw}`.toLowerCase();
    return text.includes('auth') || text.includes('授权') || text.includes('authentication') ||
      text.includes('unauthorized') || text.includes('未登录');
  }

  private handleResponse<T>(response: http.HttpResponse): RequestResult<T> {
    const raw = response.result.toString();
    if (response.responseCode < 200 || response.responseCode >= 300) {
      return {
        data: null,
        error: { code: `${response.responseCode}`, msg: raw || 'HTTP 请求失败' },
        statusCode: Number(response.responseCode),
        raw
      };
    }

    try {
      const backend = JSON.parse(raw) as BackendResponse<T>;
      if (SUCCESS_CODES.includes(backend.errorCode)) {
        return {
          data: backend.response,
          error: null,
          statusCode: Number(response.responseCode),
          raw
        };
      }
      return {
        data: null,
        error: { code: `${backend.errorCode}`, msg: backend.errorDescription || '业务请求失败' },
        statusCode: Number(response.responseCode),
        raw
      };
    } catch (error) {
      return {
        data: null,
        error: { code: 'PARSE_ERROR', msg: `响应不是 JSON: ${stringifyError(error as Object)}` },
        statusCode: Number(response.responseCode),
        raw
      };
    }
  }

  private createNetworkError<T>(error: Object): RequestResult<T> {
    return {
      data: null,
      error: { code: 'NETWORK_ERROR', msg: stringifyError(error) },
      statusCode: 0,
      raw: ''
    };
  }
}

function stringifyError(error: Object): string {
  try {
    return JSON.stringify(error);
  } catch (_) {
    return `${error}`;
  }
}

export const xmApi = new XmApi();
