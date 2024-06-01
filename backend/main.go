package main

import (
	"diagnostic/sleep_apnea_detection/backend/handlers"

	"github.com/gin-contrib/static"
	"github.com/gin-gonic/gin"
)

func handlerIndex(c *gin.Context) {
	c.HTML(200, "index.html", nil)
}
func main() {
	router := gin.Default()

	router.Use(static.Serve("/", static.LocalFile("../frontend/flutter_upload_file/build/web", false)))
	router.GET("/", handlerIndex)
	router.POST("/upload", handlers.UploadFile)
	router.GET("/status/:filename", handlers.GetStatus)
	router.GET("/results/:filename", handlers.GetResults)

	router.Run("192.168.1.128:8080")
}
