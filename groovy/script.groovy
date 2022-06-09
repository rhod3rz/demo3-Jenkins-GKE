def initApp() {
    echo 'from groovy - init the build...'
}

def buildApp() {
    echo 'from groovy - building the application...'
}

def testApp() {
    echo 'from groovy - testing the application...'
}

def deployApp() {
    echo 'from groovy - deplying the application...'
    echo "from groovy - deploying version ${params.VERSION}"
}

return this
