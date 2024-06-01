package handlers

import (
    "net/http"
    "os"
    "os/exec"
    "path/filepath"
    "strconv"
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

    channelNumberStr := c.PostForm("channel_number")
    if channelNumberStr == "" {
        channelNumberStr = "0"
    }

    channelNumber, err := strconv.Atoi(channelNumberStr)
    if err != nil {
        log.Errorf("Invalid channel number: %v", err)
        c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid channel number"})
        return
    }

    log.Infof("File received: %s", file.Filename)

    // Ensure the uploads directory exists
    err = os.MkdirAll("uploads", os.ModePerm)
    if err != nil {
        log.Errorf("Error creating uploads directory: %v", err)
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Unable to create uploads directory"})
        return
    }

    filename := filepath.Base(file.Filename)
    filePath := filepath.Join("uploads", filename)
    log.Infof("Saving file to: %s", filePath)
    if err := c.SaveUploadedFile(file, filePath); err != nil {
        log.Errorf("Error saving file: %v", err)
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Unable to save file"})
        return
    }

    log.Infof("File saved to: %s", filePath)

    go processFile(filePath, channelNumber)

    c.JSON(http.StatusOK, gin.H{"status": "File uploaded successfully", "filename": filename})
}

func GetStatus(c *gin.Context) {
    filename := c.Param("filename")
    log.Infof("Checking status for file: %s", filename)
    mu.Lock()
    status, exists := statuses[filename]
    mu.Unlock()

    if !exists {
        log.Errorf("Status not found for file: %s", filename)
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

func processFile(filePath string, channelNumber int) {
    fixedFilePath := filepath.Join("uploads", "fixed", "fixed_"+filepath.Base(filePath))
    asciiFilePath := filepath.Join("uploads", "ascii", filepath.Base(filePath)+".ascii")
    filename := filepath.Base(filePath)
    log.Infof("Processing file: %s", filename)
    mu.Lock()
    statuses[filename] = "processing"
    mu.Unlock()

    // Исправление .REC файла с помощью bash-скрипта
    log.Infof("Fixing file: %s", filePath)
    fixCmd := exec.Command("bash", "scripts/edf-hdr-repair.sh", filePath)
    fixOutput, fixErr := fixCmd.CombinedOutput()
    if fixErr != nil {
        log.Errorf("Error fixing file: %v", fixErr)
        log.Errorf("Fix Output: %s", fixOutput)
        mu.Lock()
        statuses[filename] = "fix error"
        mu.Unlock()
        return
    }

    log.Infof("File fixed: %s", fixedFilePath)

    // Конвертация .REC в ASCII с помощью Python-скрипта
    log.Infof("Converting fixed file to ASCII: %s", fixedFilePath)
    cmd := exec.Command("python", "scripts/convert_rec_to_ascii.py", fixedFilePath, asciiFilePath, strconv.Itoa(channelNumber))
    output, err := cmd.CombinedOutput()
    if err != nil {
        log.Errorf("Error converting file: %v", err)
        log.Errorf("Convert Output: %s", output)
        mu.Lock()
        statuses[filename] = "conversion error"
        mu.Unlock()
        return
    }

    log.Infof("File converted to ASCII: %s", asciiFilePath)

    mu.Lock()
    statuses[filename] = "completed"
    results[filename] = "Conversion and analysis completed"
    mu.Unlock()
}
