// entry/src/main/ets/pages/ResultPage.ets
import promptAction from '@ohos.promptAction'

interface ResultInterface {
    result?: string;
    success?: string;
}

interface ResultPageParams {
    message: string;
    wasSuccess: boolean;
}

@Builder
export function ResultPageBuilder() {
    ResultPage();
}

@Component
export struct ResultPage {
    @State message: string = "Processing result...";
    @State wasSuccess: boolean = false;
    private params: ResultPageParams | null = null;
    private navPathStack: NavPathStack | null = null;

    build() {
        NavDestination() {
            Column({ space: 20 }) {
                Text("Result")
                    .fontSize(30)
                    .fontWeight(FontWeight.Bold)
                    .margin({ top: 30, bottom: 20 })

                // Icon based on success
                Image(this.wasSuccess ? $r('app.media.ic_check_green') : $r('app.media.ic_error_red')) // Add these SVGs
                    .width(80)
                    .height(80)
                    .objectFit(ImageFit.Contain)

                Text(this.message)
                    .fontSize(18)
                    .textAlign(TextAlign.Center)
                    .margin({ left: 20, right: 20 })

                Button("Go Back to Main")
                    .onClick(() => {
                        // router.back(); // Or replace to clear history if needed
                        if (this.navPathStack) {
                            this.navPathStack.clear()
                        }
                    })
                    .margin({ top: 30 })
                    .width('80%')

            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
        }.onReady((context: NavDestinationContext) => {
            this.navPathStack = context.pathStack;

            if (context.pathInfo.param) {
                this.params = context.pathInfo.param as ResultPageParams;
                this.message = this.params?.message || "No message provided";
                this.wasSuccess = this.params?.wasSuccess || false;
            }
        })
    }
}