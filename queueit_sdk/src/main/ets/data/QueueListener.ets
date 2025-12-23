// src/main/ets/main/QueueListener.ts
import { QueuePassedInfo, QueueDisabledInfo } from './QueueModels';
import { QueueError } from './QueueError';
import { QueueItEngine } from '../main/QueueItEngine';

export interface QueueListener {
    onQueuePassed: (queuePassedInfo: QueuePassedInfo) => void;
    onQueueViewWillOpen: () => void;
    onQueueDisabled: (queueDisabledInfo: QueueDisabledInfo) => void;
    onQueueItUnavailable: () => void;
    onError: (error: QueueError, errorMessage: string) => void;
    onWebViewClosed?: () => void;
    onSessionRestart?: (queueITEngine?: QueueItEngine) => void;
    onQueueUrlChanged?: (url: string) => void;
}
