package handlers

import (
    "net/http"
    "os"
    "os/exec"
    "path/filepath"
    "sync"

    "github.com/gin-gonic/gin"
    log "github.com/sirupsen/logrus"
)

var (
    statuses = make(map[string]string)
    results  = make(map[string]string)
    mu       sync.Mutex
)


func UploadFile(c *gin.Context) {
    log.Info("Received upload request")

    file, err := c.FormFile("file")
    if err != nil {
        log.Errorf("Error receiving file: %v", err)
        c.JSON(http.StatusBadRequest, gin.H{"error": "No file is received"})
        return
    }

    log.Infof("File received: %s", file.Filename)

    // Ensure the uploads directory exists
    os.MkdirAll("uploads", os.ModePerm)

    filename := filepath.Base(file.Filename)
    filePath := filepath.Join("uploads", filename)
    if err := c.SaveUploadedFile(file, filePath); err != nil {
        log.Errorf("Error saving file: %v", err)
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Unable to save file"})
        return
    }

    log.Infof("File saved to: %s", filePath)

    go processFile(filePath)

    c.JSON(http.StatusOK, gin.H{"status": "File uploaded successfully", "filename": filename})
}

func GetStatus(c *gin.Context) {
    filename := c.Param("filename")
    mu.Lock()
    status, exists := statuses[filename]
    mu.Unlock()

    if !exists {
        c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
        return
    }

    c.JSON(http.StatusOK, gin.H{"status": status})
}

func GetResults(c *gin.Context) {
    filename := c.Param("filename")
    log.Infof("Fetching results for file: %s", filename)
    mu.Lock()
    result, exists := results[filename]
    mu.Unlock()

    if !exists {
        log.Errorf("Results not found for file: %s", filename)
        c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
        return
    }

    c.JSON(http.StatusOK, gin.H{"results": result})
}

func processFile(filePath string) {
    asciiFilename := filePath + ".ascii"
    filename := filepath.Base(filePath)
    mu.Lock()
    statuses[filename] = "processing"
    mu.Unlock()

    // Конвертация .REC в .ascii с помощью внешнего инструмента
    cmd := exec.Command("./EDFToASCII.exe", filePath, asciiFilename)
    err := cmd.Run()
    if err != nil {
        log.Errorf("Error converting file: %v", err)
        mu.Lock()
        statuses[filename] = "conversion error"
        mu.Unlock()
        return
    }

    // Запуск Python-скрипта для анализа данных
    pyCmd := exec.Command("python", "scripts/analyze_data.py", asciiFilename)
    output, err := pyCmd.CombinedOutput()
    if err != nil {
        log.Errorf("Error analyzing data: %v", err)
        mu.Lock()
        statuses[filename] = "analysis error"
        mu.Unlock()
        return
    }

    mu.Lock()
    statuses[filename] = "completed"
    results[filename] = string(output)
    mu.Unlock()
}