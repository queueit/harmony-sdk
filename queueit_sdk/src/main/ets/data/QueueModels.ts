// src/main/ets/data/QueueModels.ts

abstract class QueueInfoBase {
    constructor(public readonly queueItToken: string | null) {}
}

export class QueuePassedInfo extends QueueInfoBase {
    constructor(queueItToken: string | null) {
        super(queueItToken);
    }
}

export class QueueDisabledInfo extends QueueInfoBase {
    constructor(queueItToken: string | null) {
        super(queueItToken);
    }
}

export enum RedirectType {
    Unknown = 'unknown',
    Queue = 'queue',
    SafetyNet = 'safetynet',
    AfterEvent = 'afterevent',
    Disabled = 'disabled',
    DirectLink = 'directLink',
    Idle = 'idle'
}

export class QueueTryPassResult {
    constructor(
        public readonly queueItToken: string | null,
        public readonly queueUrl: string | null,
        public readonly targetUrl: string | null,
        public readonly isPassedThrough: boolean,
        public readonly redirectType: RedirectType,
        public readonly urlTTLInMinutes: number | null,
    ) {
    }
}

export class QueueItEngineOptions {
    disableBackButtonFromWR: boolean = true; // Default
    webViewUserAgent?: string; // Optional custom user agent for the webview
    viewDelayMs: number = 0; // Delay before showing queue view
}