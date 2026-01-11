package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// --- 基础工具函数 ---

func read7BitEncodedInt(r *bytes.Reader) (int, error) {
	count := 0
	shift := 0
	for {
		b, err := r.ReadByte()
		if err != nil { return 0, err }
		count |= (int(b) & 0x7F) << shift
		shift += 7
		if (b & 0x80) == 0 { break }
	}
	return count, nil
}

func write7BitEncodedInt(w *bytes.Buffer, value int) {
	v := uint32(value)
	for v >= 0x80 {
		w.WriteByte(byte(v | 0x80))
		v >>= 7
	}
	w.WriteByte(byte(v))
}

func getValheimStableHashCode(s string) int32 {
	h1 := int32(5381)
	h2 := int32(5381)
	for i := 0; i < len(s); i++ {
		c := int32(s[i])
		if i%2 == 0 {
			h1 = ((h1 << 5) + h1) ^ c
		} else {
			h2 = ((h2 << 5) + h2) ^ c
		}
	}
	return h1 + (h2 * 1566083941)
}

// --- 主程序 ---
func main() {
	// 0. 参数校验 (修复部分)
	if len(os.Args) < 4 {
		fmt.Printf("[Patcher] ❌ Invalid args. Usage: %s <worldName> <saveDir> <seed>\n", filepath.Base(os.Args[0]))
		os.Exit(1)
	}
	
	worldName := os.Args[1]
	saveDir := os.Args[2]
	targetSeed := os.Args[3]

	if targetSeed == "" {
		fmt.Println("[Patcher] ℹ️  No target seed provided. Skipping.")
		return
	}

	localSavesPath := filepath.Join(saveDir, "worlds_local")
	mainFwlPath := filepath.Join(localSavesPath, worldName+".fwl")
	dbPath := filepath.Join(localSavesPath, worldName+".db")

	// 1. 寻找“真理”文件 (最新的 backup_auto)
	pattern := filepath.Join(localSavesPath, worldName+"*.fwl")
	matches, err := filepath.Glob(pattern)
	
	var sourceFile string

	if err == nil && len(matches) > 0 {
		// 先尝试找备份文件
		var backupFiles []string
		for _, m := range matches {
            // 【关键点】这里使用了 strings 包，消除了编译错误
			if strings.Contains(filepath.Base(m), "_backup_auto-") {
				backupFiles = append(backupFiles, m)
			}
		}

		if len(backupFiles) > 0 {
			// 排序取最新的一个
			sort.Strings(backupFiles)
			sourceFile = backupFiles[len(backupFiles)-1]
			fmt.Printf("[Patcher] 🔍 Analyzing backup file: %s\n", filepath.Base(sourceFile))
		} else {
			// 没有备份，检查主文件
			if _, err := os.Stat(mainFwlPath); err == nil {
				sourceFile = mainFwlPath
				fmt.Printf("[Patcher] ⚠️  No backup found. Analyzing main file: %s\n", filepath.Base(sourceFile))
			}
		}
	}

	if sourceFile == "" {
		fmt.Println("[Patcher] ℹ️  No existing world files found. Ready for random generation.")
		return
	}

	// 2. 读取当前种子
	currentSeed, err := readSeed(sourceFile)
	if err != nil {
		fmt.Printf("[Patcher] ❌ Failed to read seed from %s: %v\n", filepath.Base(sourceFile), err)
		return
	}

	// 3. 核心校验
	if currentSeed == targetSeed {
		fmt.Printf("[Patcher] ✅ Verification passed: Seed matches (%s). No action taken.\n", currentSeed)
		return
	}

	fmt.Printf("[Patcher] 🛑 Seed Mismatch! Current: [%s] vs Target: [%s]\n", currentSeed, targetSeed)
	fmt.Println("[Patcher] 🔧 Initiating fix procedure...")

	// 4. 执行修改逻辑
	patchedData, err := generatePatchedData(sourceFile, targetSeed)
	if err != nil {
		fmt.Printf("[Patcher] ❌ Failed to patch data: %v\n", err)
		return
	}

	// A. 写入源文件 (Backup)
	// 如果源文件就是主文件，这一步其实和 B 重复，但为了逻辑统一保留无妨
	err = os.WriteFile(sourceFile, patchedData, 0644)
	if err != nil {
		fmt.Printf("[Patcher] ❌ Failed to write source: %v\n", err)
		return
	}
	fmt.Printf("[Patcher] 📝 Updated source file: %s\n", filepath.Base(sourceFile))

	// B. 覆盖主文件 (Main FWL)
	err = os.WriteFile(mainFwlPath, patchedData, 0644)
	if err != nil {
		fmt.Printf("[Patcher] ❌ Failed to update main FWL: %v\n", err)
		return
	}
	fmt.Printf("[Patcher] 📝 Synchronized main file: %s\n", filepath.Base(mainFwlPath))

	// C. 删除 DB
	if _, err := os.Stat(dbPath); err == nil {
		os.Remove(dbPath)
		fmt.Printf("[Patcher] ♻️  DB file (%s) deleted. World will regenerate on start.\n", filepath.Base(dbPath))
	} else {
		fmt.Println("[Patcher] ℹ️  No DB file found (Fresh start?).")
	}
}

// --- 核心逻辑函数 ---

func readSeed(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil { return "", err }
	reader := bytes.NewReader(data)

	// 跳过 Version(4) + Size(4)
	reader.Seek(8, io.SeekStart)

	nameLen, err := read7BitEncodedInt(reader)
	if err != nil { return "", err }
	reader.Seek(int64(nameLen), io.SeekCurrent)

	seedLen, err := read7BitEncodedInt(reader)
	if err != nil { return "", err }
	
	seedBytes := make([]byte, seedLen)
	_, err = reader.Read(seedBytes)
	return string(seedBytes), err
}

func generatePatchedData(path string, targetSeed string) ([]byte, error) {
	data, err := os.ReadFile(path)
	if err != nil { return nil, err }
	reader := bytes.NewReader(data)

	var version int32
	binary.Read(reader, binary.LittleEndian, &version)
	reader.Seek(4, io.SeekCurrent)

	nameLen, _ := read7BitEncodedInt(reader)
	reader.Seek(int64(nameLen), io.SeekCurrent)
	
	headerSize := len(data) - reader.Len()

	oldSeedLen, _ := read7BitEncodedInt(reader)
	oldSeedBytes := make([]byte, oldSeedLen)
	reader.Read(oldSeedBytes)
	oldSeed := string(oldSeedBytes)

	expectedOldHash := getValheimStableHashCode(oldSeed)
	var gapData []byte
	foundHash := false

	for i := 0; i < 256; i++ {
		currentPos, _ := reader.Seek(0, io.SeekCurrent)
		var candidateHash int32
		err := binary.Read(reader, binary.LittleEndian, &candidateHash)
		if err == nil && candidateHash == expectedOldHash {
			foundHash = true
			break
		}
		reader.Seek(currentPos, io.SeekStart)
		b, _ := reader.ReadByte()
		gapData = append(gapData, b)
	}

	if !foundHash {
		// 为了防止编译错误，这里也简单处理 error
		return nil, fmt.Errorf("structure mismatch")
	}

	restData, _ := io.ReadAll(reader)

	newBuf := new(bytes.Buffer)
	newBuf.Write(data[:headerSize])
	write7BitEncodedInt(newBuf, len(targetSeed))
	newBuf.WriteString(targetSeed)
	if len(gapData) > 0 {
		newBuf.Write(gapData)
	}
	newHash := getValheimStableHashCode(targetSeed)
	binary.Write(newBuf, binary.LittleEndian, newHash)
	newBuf.Write(restData)

	return newBuf.Bytes(), nil
}