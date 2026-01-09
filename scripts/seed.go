package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

func read7BitEncodedInt(r *bytes.Reader) (int, error) {
	count := 0
	shift := 0
	for {
		b, err := r.ReadByte()
		if err != nil {
			return 0, err
		}
		count |= (int(b) & 0x7F) << shift
		shift += 7
		if (b & 0x80) == 0 {
			break
		}
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

func getDotNetHashCode(s string) int32 {
	var hash int32
	for _, c := range s {
		hash = (hash << 5) - hash + int32(c)
	}
	return hash
}

func main() {
	if len(os.Args) < 4 {
		fmt.Println("Usage: patcher <world_name> <save_dir> <target_seed>")
		os.Exit(1)
	}

	worldName := os.Args[1]
	saveDir := os.Args[2]
	targetSeed := os.Args[3]

	fwlPath := filepath.Join(saveDir, "worlds_local", worldName+".fwl")
	dbPath := filepath.Join(saveDir, "worlds_local", worldName+".db")

	if _, err := os.Stat(fwlPath); os.IsNotExist(err) {
		fmt.Printf("[Patcher] File not found: %s. Skipping.\n", fwlPath)
		return
	}

	data, err := os.ReadFile(fwlPath)
	if err != nil {
		panic(err)
	}
	reader := bytes.NewReader(data)

	// 1. Version
	var version int32
	binary.Read(reader, binary.LittleEndian, &version)

	// 2. Padding (Skip 4 bytes, based on your previous logs)
	reader.Seek(4, io.SeekCurrent)

	// 3. World Name
	nameLen, _ := read7BitEncodedInt(reader)
	reader.Seek(int64(nameLen), io.SeekCurrent)

	// 4. Current Seed String
	// 记录种子字符串之前的头部数据，用于后续重写
	headerSize := len(data) - reader.Len()
	
	oldSeedLen, _ := read7BitEncodedInt(reader)
	oldSeedBytes := make([]byte, oldSeedLen)
	reader.Read(oldSeedBytes)
	currentSeed := string(oldSeedBytes)

	fmt.Printf("[Patcher] Found Current Seed: [%s]\n", currentSeed)

	// ========================================================
	// 🧠 智能定位 Hash 逻辑
	// 不假设 Hash 在哪里，而是根据旧种子算出来的 Hash 去“寻找”它
	// ========================================================
	
	// 1. 计算旧种子的预期 Hash
	expectedOldHash := getDotNetHashCode(currentSeed)
	fmt.Printf("[Patcher] Expected Old Hash: %d (Scanning to find this...)\n", expectedOldHash)

	// 2. 向后扫描寻找这个 Hash
	var gapData []byte
	foundHash := false
	
	// 最多向后找 128 字节 (足够容纳 UID 和其他可能的 padding)
	for i := 0; i < 128; i++ {
		// 记录当前位置
		currentPos, _ := reader.Seek(0, io.SeekCurrent)
		
		// 尝试读 4 字节
		var candidateHash int32
		err := binary.Read(reader, binary.LittleEndian, &candidateHash)
		
		// 如果读到了末尾，停止
		if err != nil {
			break
		}

		// 检查是否匹配
		if candidateHash == expectedOldHash {
			foundHash = true
			fmt.Printf("[Patcher] ✅ Found Hash at relative offset +%d bytes!\n", i)
			break
		}

		// 如果不匹配，回退 3 个字节 (前进 1 个字节继续扫)
		// 并把这 1 个字节加入到 gapData
		reader.Seek(currentPos, io.SeekStart)
		b, _ := reader.ReadByte()
		gapData = append(gapData, b)
	}

	if !foundHash {
		fmt.Println("[Patcher] ❌ FATAL: Could not locate old Hash in file! File structure unknown.")
		// 这种情况下最好不要强行修改，以免坏档
		return 
	}

	// 此时 reader 正好停在 Old Hash 之后
	restData, _ := io.ReadAll(reader)

	// ========================================================
	// 重组文件
	// ========================================================
	newBuf := new(bytes.Buffer)

	// A. Header (Version + Name)
	newBuf.Write(data[:headerSize])

	// B. New Seed String
	write7BitEncodedInt(newBuf, len(targetSeed))
	newBuf.WriteString(targetSeed)

	// C. Gap Data (UID/Padding, preserved exactly as is)
	if len(gapData) > 0 {
		newBuf.Write(gapData)
		fmt.Printf("[Patcher] Preserving %d bytes of gap data (UID?)\n", len(gapData))
	}

	// D. New Hash
	newHash := getDotNetHashCode(targetSeed)
	binary.Write(newBuf, binary.LittleEndian, newHash)
	fmt.Printf("[Patcher] Writing New Hash: %d\n", newHash)

	// E. Rest of file
	newBuf.Write(restData)

	// Save
	os.WriteFile(fwlPath, newBuf.Bytes(), 0644)
	fmt.Println("[Patcher] FWL patched successfully.")

	// Delete DB
	if _, err := os.Stat(dbPath); err == nil {
		os.Remove(dbPath)
		fmt.Println("[Patcher] ♻️  DB Deleted. Server will regenerate correct map.")
	}
}