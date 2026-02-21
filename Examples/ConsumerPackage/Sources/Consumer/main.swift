import SamplePackage

@main
struct ConsumerMain {
    static func main() {
        let lib = SampleLibrary()
        print(lib.greet())
    }
}
