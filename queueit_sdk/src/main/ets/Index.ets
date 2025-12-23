// src/main/ets/index.ets
// This file defines the public API of the Queue-it ArkTS SDK.
// Application developers will import SDK components from here.

// --- Core Engine & Listener ---
export { QueueItEngine } from './main/QueueItEngine';

// Exporting the type is important for implementing the listener
export type { QueueListener } from './data/QueueListener';

// --- Data Models & Configuration ---
export {
    QueuePassedInfo,
    QueueDisabledInfo,
    QueueTryPassResult, // Export if developers might use tryPass() directly
    RedirectType,
    QueueItEngineOptions // Export for configuration
} from './data/QueueModels';

// --- Error Handling ---
export { QueueError } from './data/QueueError';

// --- UI Components & Management (Recommended Integration) ---
// Export the ArkUI component itself
export { QueueView } from './components/QueueView';

// Export the manager needed to control the QueueView state via @Link
export { QueueItViewManager as QueueITViewManager } from './view/QueueItViewManager';

export { QueueItApiClient as QueueITApiClient } from './networking/QueueItApiClient';

export { Logger } from './utils/Logger';

export { UserAgentManager } from './utils/UserAgentManager';
