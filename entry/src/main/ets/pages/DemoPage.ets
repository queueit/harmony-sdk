// entry/src/main/ets/pages/Index.ets

import {
    QueueItEngine,
    QueueListener,
    QueuePassedInfo,
    QueueDisabledInfo,
    QueueError,
    QueueView,
    QueueITViewManager,
    QueueItEngineOptions,
    QueueTryPassResult,
    RedirectType,
    Logger,
    QueueITApiClient
} from 'queueit-library';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import preferences from '@ohos.data.preferences';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

// --- Preference Constants for Demo App Inputs & SDK State ---
const DEMO_PREFS_NAME = 'queueit_demo_app_prefs';
const KEY_CUSTOMER_ID = 'customerId';
const KEY_EVENT_ID = 'eventOrAliasId';
const KEY_LAYOUT_NAME = 'layoutName';
const KEY_LANGUAGE = 'language';
const KEY_ENQUEUE_TOKEN_INPUT = 'enqueueToken'; // Input field value
const KEY_ENQUEUE_KEY_INPUT = 'enqueueKey'; // Input field value

@Builder
export function DemoPageBuilder() {
    DemoPage();
}

@Component
struct DemoPage {
    // --- SDK Related State ---
    private engine: QueueItEngine | null = null;
    @State queueViewManager: QueueITViewManager | null = null;
    @State sdkQueueToken: string | null = null; // Token received from SDK
    @State sdkQueueErrorMsg: string = '';
    @State isLoadingSdk: boolean = false;

    // --- Demo App Input Fields State ---
    @State customerIdInput: string = '';
    @State eventIdInput: string = '';
    @State layoutNameInput: string = '';
    @State languageInput: string = '';
    @State enqueueTokenInput: string = '';
    @State enqueueKeyInput: string = '';
    @State isTestEnvironment: boolean = true;

    // --- Input Validation State ---
    @State customerIdError: string = '';
    @State eventIdError: string = '';

    // --- TryPass related State ---
    @State tryPassResultInternal: QueueTryPassResult | null = null;
    @State isShowQueueButtonEnabled: boolean = false;

    // --- Navigation Stack ---
    @State navPathStack: NavPathStack = new NavPathStack();

    // --- Preference Helpers for Demo App ---
    async getDemoPreferences(): Promise<preferences.Preferences> {
        const context = this.getUIContext()?.getHostContext() as common.Context;
        return await preferences.getPreferences(context, DEMO_PREFS_NAME);
    }

    async loadDemoInputs() {
        try {
            const prefs = await this.getDemoPreferences();
            this.customerIdInput = await prefs.get(KEY_CUSTOMER_ID, '') as string;
            this.eventIdInput = await prefs.get(KEY_EVENT_ID, '') as string;
            this.layoutNameInput = await prefs.get(KEY_LAYOUT_NAME, '') as string;
            this.languageInput = await prefs.get(KEY_LANGUAGE, '') as string;
            this.enqueueTokenInput = await prefs.get(KEY_ENQUEUE_TOKEN_INPUT, '') as string;
            this.enqueueKeyInput = await prefs.get(KEY_ENQUEUE_KEY_INPUT, '') as string;
            this.validateAllInputs(); // Validate loaded inputs
        } catch (e) {
            console.error("IndexPage: Error loading demo inputs:", JSON.stringify(e));
        }
    }

    async saveDemoInputs() {
        try {
            const prefs = await this.getDemoPreferences();
            await prefs.put(KEY_CUSTOMER_ID, this.customerIdInput);
            await prefs.put(KEY_EVENT_ID, this.eventIdInput);
            await prefs.put(KEY_LAYOUT_NAME, this.layoutNameInput);
            await prefs.put(KEY_LANGUAGE, this.languageInput);
            await prefs.put(KEY_ENQUEUE_TOKEN_INPUT, this.enqueueTokenInput);
            await prefs.put(KEY_ENQUEUE_KEY_INPUT, this.enqueueKeyInput);
            await prefs.flush();
        } catch (e) {
            console.error("IndexPage: Error saving demo inputs:", JSON.stringify(e));
        }
    }

    // --- End Demo Prefs ---

    // --- Input Validation ---
    validateField(value: string, isAlphaNumericOnly: boolean = true): string {
        if (!value || value.trim().length === 0) {
            return "Field required";
        }
        if (isAlphaNumericOnly && !/^[a-zA-Z0-9]*$/.test(value)) {
            return "Must be alphanumeric";
        }
        return "";
    }

    validateAllInputs(): boolean {
        this.customerIdError = this.validateField(this.customerIdInput);
        this.eventIdError = this.validateField(this.eventIdInput);
        return !this.customerIdError && !this.eventIdError;
    }

    // --- QueueListener Implementation ---
    private createQueueListener(): QueueListener {
        return {
            onQueuePassed: (info: QueuePassedInfo) => {
                this.isLoadingSdk = false;
                this.sdkQueueToken = info.queueItToken;
                this.sdkQueueErrorMsg = '';
                this.queueViewManager?.hideQueue();
                this.navigateToResultPage(`You passed the queue! Your token: ${info.queueItToken}`, true);
            },
            onQueueViewWillOpen: () => {
                this.isLoadingSdk = false;
                promptAction.showToast({ message: 'Queue view will open' });
            },
            onQueueDisabled: (info: QueueDisabledInfo) => {
                this.isLoadingSdk = false;
                this.sdkQueueToken = info.queueItToken; // Treat as passed
                this.sdkQueueErrorMsg = '';
                this.queueViewManager?.hideQueue();
                this.navigateToResultPage(`The queue is disabled. Your token: ${info.queueItToken}`, false);
            },
            onQueueItUnavailable: () => {
                this.isLoadingSdk = false;
                this.sdkQueueErrorMsg = "Queue-it Unavailable";
                this.queueViewManager?.hideQueue();
                this.navigateToResultPage("Queue-it is unavailable. Please try again later.", false);
            },
            onError: (error: QueueError, errorMessage: string) => {
                this.isLoadingSdk = false;
                this.sdkQueueErrorMsg = `Error: ${errorMessage}`;
                this.queueViewManager?.hideQueue();
                this.navigateToResultPage(`Critical error: ${errorMessage}`, false);
            },
            onWebViewClosed: () => {
                if (!this.sdkQueueToken) {
                    promptAction.showToast({ message: "Queue process cancelled." })
                }
                this.isLoadingSdk = false;
            },
            onSessionRestart: (engineInstance?: QueueItEngine) => { // Engine instance passed back
                promptAction.showToast({ message: "Restarting queue session..." });
                this.isLoadingSdk = true;
                this.sdkQueueErrorMsg = '';
                this.sdkQueueToken = null;
                this.tryPassResultInternal = null;
                this.isShowQueueButtonEnabled = false;
                try {
                    (engineInstance || this.engine)?.run();
                } catch (e) {
                    console.error("Error on session restart run:", e);
                    this.isLoadingSdk = false;
                }
            }
        };
    }
    // --- End QueueListener ---

    async initializeSdkEngine() {
        if (!this.validateAllInputs()) {
            promptAction.showToast({ message: "Please correct input fields." });
            return false;
        }
        // Save inputs before initializing engine
        await this.saveDemoInputs();

        const context = this.getUIContext()?.getHostContext() as common.Context;

        const listener = this.createQueueListener();
        const options = new QueueItEngineOptions(); // Use defaults or add inputs for options
        options.disableBackButtonFromWR = true; //disable back button

        Logger.setLogLevel(hilog.LogLevel.DEBUG); //change SDK log level

        try {
            this.engine = new QueueItEngine(
                context,
                this.customerIdInput,
                this.eventIdInput,
                listener,
                this.navPathStack,
                this.layoutNameInput || undefined, // Pass undefined if empty
                this.languageInput || undefined,
                options
            );
            this.queueViewManager = this.engine.getWebViewManager(); // CRITICAL for <QueueView>
            return true;
        } catch (e) {
            console.error("IndexPage: Error initializing QueueItEngine:", JSON.stringify(e));
            this.sdkQueueErrorMsg = "Failed to initialize SDK";
            this.isLoadingSdk = false;
            return false;
        }
    }

    async aboutToAppear() {
        await this.loadDemoInputs(); // Load saved inputs for the demo page
    }

    async handleRunEngine() {
        this.sdkQueueErrorMsg = '';
        this.sdkQueueToken = null;
        this.tryPassResultInternal = null;
        this.isShowQueueButtonEnabled = false;

        await this.initializeSdkEngine(); //initialise new SdkEngine every run.

        QueueITApiClient.isTest = this.isTestEnvironment;

        this.isLoadingSdk = true;
        try {
            if (this.enqueueTokenInput) {
                await this.engine!.runWithEnqueueToken(this.enqueueTokenInput);
            } else if (this.enqueueKeyInput) {
                await this.engine!.runWithEnqueueKey(this.enqueueKeyInput);
            } else {
                await this.engine!.run();
            }
        } catch (e) {
            this.isLoadingSdk = false;
            this.sdkQueueErrorMsg = "Error running engine: " + e.message;
            promptAction.showToast({ message: this.sdkQueueErrorMsg });
        }
    }

    async handleTryPass() {
        this.sdkQueueErrorMsg = '';
        this.sdkQueueToken = null;
        this.tryPassResultInternal = null;
        this.isShowQueueButtonEnabled = false;

        await this.initializeSdkEngine(); //initialise new SdkEngine every run.
        QueueITApiClient.isTest = this.isTestEnvironment;

        this.isLoadingSdk = true;
        try {
            const result: QueueTryPassResult | null = await this.engine!.tryPass(
                this.enqueueTokenInput,
                this.enqueueKeyInput
            );
            this.isLoadingSdk = false;
            if (result) {
                this.tryPassResultInternal = result;
                promptAction.showToast({ message: `TryPass Status: ${result.redirectType}` });
                if (result.redirectType === RedirectType.Queue) {
                    this.isShowQueueButtonEnabled = true;
                } else if (result.isPassedThrough) {
                    this.sdkQueueToken = result.queueItToken;
                    this.navigateToResultPage(`Passed via TryPass! Token: ${result.queueItToken}`, true);
                } else if (result.redirectType === RedirectType.Disabled ||
                    result.redirectType === RedirectType.AfterEvent || result.redirectType === RedirectType.Idle) {
                    this.sdkQueueToken = result.queueItToken;
                    this.navigateToResultPage(`Queue disabled via TryPass. Token: ${result.queueItToken}`, false);
                }
            } else {
                this.sdkQueueErrorMsg = "tryPass returned null";
            }
        } catch (e) {
            this.isLoadingSdk = false;
            this.sdkQueueErrorMsg = "Error in tryPass: " + e.message;
        }
    }

    handleShowQueue() {
        if (this.engine && this.tryPassResultInternal &&
            this.tryPassResultInternal.redirectType === RedirectType.Queue) {
            this.isLoadingSdk = true; // Indicate action
            this.engine.showQueue(this.tryPassResultInternal);
            // isLoadingSdk will be managed by callbacks
        } else {
            promptAction.showToast({ message: "No queue to show or result not 'Queue'." });
        }
        this.isShowQueueButtonEnabled = false; // Reset after attempting to show
    }

    navigateToResultPage(resultText: string, success: boolean) {
        this.navPathStack.pushPath({
            //replace the QueueView Page
            name: 'ResultPage',
            param: new Object({
                message: resultText,
                wasSuccess: success
            })
        });
    }

    build() {
        NavDestination() {
            Navigation(this.navPathStack) {
                Column() {
                    Scroll() {
                        Column({ space: 8 }) {
                            Text("Queue-it ArkTS Demo")
                                .fontSize(24)
                                .fontWeight(FontWeight.Bold)
                                .margin({ top: 10, bottom: 10 })

                            // --- Input Fields ---
                            TextInput({ placeholder: 'Customer ID*', text: this.customerIdInput })
                                .onChange((value) => {
                                    this.customerIdInput = value;
                                    this.customerIdError = this.validateField(value);
                                })
                            if (this.customerIdError) {
                                Text(this.customerIdError).fontColor(Color.Red).fontSize(12)
                            }

                            TextInput({ placeholder: 'Event ID/Alias*', text: this.eventIdInput })
                                .onChange((value) => {
                                    this.eventIdInput = value;
                                    this.eventIdError = this.validateField(value);
                                })
                            if (this.eventIdError) {
                                Text(this.eventIdError).fontColor(Color.Red).fontSize(12)
                            }

                            TextInput({ placeholder: 'Layout Name', text: this.layoutNameInput })
                                .onChange((value) => {
                                    this.layoutNameInput = value;
                                })
                            TextInput({ placeholder: 'Language', text: this.languageInput })
                                .onChange((value) => {
                                    this.languageInput = value;
                                })
                            TextInput({ placeholder: 'Enqueue Token', text: this.enqueueTokenInput })
                                .onChange((value) => {
                                    this.enqueueTokenInput = value;
                                })
                            TextInput({ placeholder: 'Enqueue Key', text: this.enqueueKeyInput })
                                .onChange((value) => {
                                    this.enqueueKeyInput = value;
                                })

                            Row() {
                                Radio({ value: 'test', group: 'envGroup' }).checked(this.isTestEnvironment)
                                    .onChange((isChecked) => {
                                        if (isChecked) {
                                            this.isTestEnvironment = true;
                                        }
                                    })
                                Text(' Test Env').margin({ left: 5 })
                                Radio({ value: 'prod', group: 'envGroup' })
                                    .checked(!this.isTestEnvironment)
                                    .margin({ left: 15 })
                                    .onChange((isChecked) => {
                                        if (isChecked) {
                                            this.isTestEnvironment = false;
                                        }
                                    })
                                Text(' Prod Env').margin({ left: 5 })
                            }.margin({ top: 5, bottom: 5 })

                            // --- Action Buttons ---
                            Button('Run with Queue-it Engine')
                                .onClick(() => this.handleRunEngine())
                                .width('90%').margin({ top: 10 })

                            Button('Run with Session Engine (TryPass)')
                                .onClick(() => this.handleTryPass())
                                .width('90%').margin({ top: 5 })

                            Button('Show Queue (after TryPass)')
                                .onClick(() => this.handleShowQueue())
                                .width('90%').margin({ top: 5 })

                            // --- Status Display ---
                            if (this.isLoadingSdk) {
                                Row() {
                                    LoadingProgress().width(20).height(20).margin({ right: 5 });
                                    Text("SDK Processing...")
                                }.margin(5)
                            } else if (this.sdkQueueToken) {
                                Text(`Status: Passed (SDK Token OK)`).fontColor(Color.Green).margin(5)
                            } else if (this.sdkQueueErrorMsg) {
                                Text(`Status: ${this.sdkQueueErrorMsg}`).fontColor(Color.Red).margin(5)
                            }

                        }
                        .width('100%').padding({ left: 16, right: 16, bottom: 10 })
                    }
                    .layoutWeight(1) // Allows ScrollView to take space before QueueView
                }
                .width('100%')
                .height('100%')
            }
            .navDestination(this.queueItMap)
            .mode(NavigationMode.Auto)
        }
        .hideTitleBar(true) //hide parent rootPathStack
    }

    @Builder
    queueItMap(name: string) {
        if (name === 'QueueView') {
            QueueView({ viewManager: $queueViewManager })
        }
    }
}


