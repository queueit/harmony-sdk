// entry/src/main/ets/pages/Index.ets

@Entry
@Component
struct IndexPage {
    // --- Navigation Stack ---
    @State rootPathStack: NavPathStack = new NavPathStack();

    navigateToDemoPage() {
        this.rootPathStack.pushPath({
            name: 'DemoPage',
            param: null
        });
    }

    navigateToDemoWithProtectedAPIPage() {
        this.rootPathStack.pushPath({
            name: 'DemoWithProtectedAPIPage',
            param: null
        });
    }

    build() {
        Navigation(this.rootPathStack) {
            Column() {
                Scroll() {
                    Column({ space: 8 }) {
                        Text("Queue-it ArkTS Demo")
                            .fontSize(24)
                            .fontWeight(FontWeight.Bold)
                            .margin({ top: 10, bottom: 10 })

                        Button('Open Demo')
                            .onClick(() => this.navigateToDemoPage())
                            .width('90%').margin({ top: 10 })

                        Button('Open Demo with protected API')
                            .onClick(() => this.navigateToDemoWithProtectedAPIPage())
                            .width('90%').margin({ top: 5 })

                    }
                    .width('100%').padding({ left: 16, right: 16, bottom: 10 })
                }
                .layoutWeight(1) // Allows ScrollView to take space before QueueView
            }
            .width('100%')
            .height('100%')
        }
        .mode(NavigationMode.Auto)
    }
}


