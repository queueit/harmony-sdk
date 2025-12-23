import { QueueError } from "./QueueError";
import { QueueTryPassResult } from "./QueueModels";

export interface QueueItWaitingRoomProviderResult {
  shouldEnqueue: boolean;
  result?: QueueTryPassResult;
  error?: QueueError;
  errorMessage?: string;
}
