export interface RequestError {
  code: string;
  msg: string;
}

export interface RequestResult<T> {
  data: T | null;
  error: RequestError | null;
  statusCode: number;
  raw: string;
}

export interface BackendResponse<T> {
  errorCode: number;
  errorDescription: string;
  response: T;
}

export interface PictureCodeResponse {
  pictureCode: string;
  key: string;
}

export interface SendCodeForLogonNewResponse {
  firstRegisterFlag: number;
}

export interface VerifyCodeResponse {
  verificationCodeStatus: number;
}

export interface LoginResponse {
  loginToken: string;
}

export interface UserInfo {
  nickName: string;
  avatarUrl: string;
  phones: Array<string>;
}

export interface DoorAccessQrKey {
  createTimeMs: number;
  webQRCode: string;
}

export interface DoorAccessQrResponse {
  topKeys: Array<DoorAccessQrKey>;
}
