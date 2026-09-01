// A simple hello world example.
package main

import (
	"fmt"
	"runtime"
)

func main() {
	fmt.Println("Hello, World from Docker Go!")
	fmt.Printf("Go version: %s\n", runtime.Version())
	fmt.Printf("Platform: %s/%s\n", runtime.GOOS, runtime.GOARCH)
}
