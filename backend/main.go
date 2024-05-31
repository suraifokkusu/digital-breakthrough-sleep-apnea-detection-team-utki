package main

import (
    "github.com/gin-gonic/gin"
    "sleep_apnea_detection/handlers"
)

func main() {
    router := gin.Default()

    router.POST("/upload", handlers.UploadFile)
    router.GET("/status/:filename", handlers.GetStatus)
    router.GET("/results/:filename", handlers.GetResults)

    router.Run(":8080")
}
