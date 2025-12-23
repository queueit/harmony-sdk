export interface EnqueueRequestBody {
  userId: string;
  userAgent: string;
  sdkVersion: string;
  layoutName?: string;
  language?: string;
  enqueueToken?: string;
  enqueueKey?: string;
}

export interface EnqueueSuccessResponse { //need upper letter on json parse
  QueueId?: string;
  QueueUrl?: string;
  QueueUrlTTLInMinutes?: number;
  EventTargetUrl?: string;
  QueueitToken?: string;
}
