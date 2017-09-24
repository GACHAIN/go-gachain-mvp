ts (Terminal Size)
==

[![Build Status](https://travis-ci.org/olekukonko/ts.png?branch=master)](https://travis-ci.org/olekukonko/ts) [![Total views](https://sourcegraph.com/api/repos/github.com/GACHAIN/go-gachain-mvp/vendor/src/github.com/olekukonko/ts/counters/views.png)](https://sourcegraph.com/github.com/GACHAIN/go-gachain-mvp/vendor/src/github.com/olekukonko/ts)

Simple go Application to get Terminal Size. So Many Implementations do not support windows but `ts` has full windows support.
Run `go get github.com/GACHAIN/go-gachain-mvp/vendor/src/github.com/olekukonko/ts` to download and install

#### Example

```go
package main

import (
	"fmt"
	"github.com/GACHAIN/go-gachain-mvp/vendor/src/github.com/olekukonko/ts"
)

func main() {
	size, _ := ts.GetSize()
	fmt.Println(size.Col())  // Get Width
	fmt.Println(size.Row())  // Get Height
	fmt.Println(size.PosX()) // Get X position
	fmt.Println(size.PosY()) // Get Y position
}
```

[See Documentation](http://godoc.org/github.com/GACHAIN/go-gachain-mvp/vendor/src/github.com/olekukonko/ts)
