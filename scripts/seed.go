package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// read7BitEncodedInt 读取 .NET 格式的可变长度整数
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

// write7BitEncodedInt 写入 .NET 格式的可变长度整数
func write7BitEncodedInt(w *bytes.Buffer, value int) {
	v := uint32(value)
	for v >= 0x80 {
		w.WriteByte(byte(v | 0x80))
		v >>= 7
	}
	w.WriteByte(byte(v))
}

// getDotNetHashCode 模拟 Unity/Mono 的 string.GetHashCode()
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
		fmt.Printf("[Patcher] No existing world file found at %s. Skipping.\n", fwlPath)
		return
	}

	fmt.Printf("[Patcher] Inspecting world: %s\n", worldName)

	data, err := os.ReadFile(fwlPath)
	if err != nil {
		fmt.Printf("[Patcher] Error reading file: %v\n", err)
		os.Exit(1)
	}
	reader := bytes.NewReader(data)

	// 1. 读取版本号 [Int32]
	var version int32
	if err := binary.Read(reader, binary.LittleEndian, &version); err != nil {
		fmt.Println("[Patcher] Failed to read version")
		os.Exit(1)
	}

	// ========================================================
	// ⚠️ 修复点：跳过 header 中的额外 4 字节 (Int32)
	// 根据你的 hexdump，版本号之后紧跟一个 Int32 (36)
	// ========================================================
	if _, err := reader.Seek(4, io.SeekCurrent); err != nil {
		fmt.Println("[Patcher] Failed to skip header padding")
		os.Exit(1)
	}

	// 2. 读取世界名长度 [7-bit Int]
	nameLen, err := read7BitEncodedInt(reader)
	if err != nil {
		fmt.Println("[Patcher] Failed to read name length")
		os.Exit(1)
	}
	
	// 3. 跳过世界名
	if _, err := reader.Seek(int64(nameLen), io.SeekCurrent); err != nil {
		fmt.Println("[Patcher] Failed to skip world name")
		os.Exit(1)
	}

	// 4. [String SeedName] -> 这里是我们定位的种子起点
	seedStartOffset := len(data) - reader.Len()
	
	currentSeedLen, err := read7BitEncodedInt(reader)
	if err != nil {
		fmt.Println("[Patcher] Failed to read seed length")
		os.Exit(1)
	}
	
	currentSeedBytes := make([]byte, currentSeedLen)
	if _, err := reader.Read(currentSeedBytes); err != nil {
		fmt.Println("[Patcher] Failed to read seed string")
		os.Exit(1)
	}
	currentSeed := string(currentSeedBytes)

	fmt.Printf("[Patcher] Current Seed: [%s] | Target Seed: [%s]\n", currentSeed, targetSeed)

	if currentSeed == targetSeed {
		fmt.Println("[Patcher] ✅ Seed matches. No changes needed.")
		return
	}

	fmt.Println("[Patcher] ⚠️  Seed MISMATCH! Patching FWL and resetting DB...")

	// 5. 跳过旧 Hash (4 字节)
	if _, err := reader.Seek(4, io.SeekCurrent); err != nil {
		fmt.Println("[Patcher] Failed to skip old hash")
		os.Exit(1)
	}
	restData, _ := io.ReadAll(reader)

	// 6. 重组文件
	newBuf := new(bytes.Buffer)
	
	// A. 写入头部 (Version + Padding + WorldNameLength + WorldName)
	newBuf.Write(data[:seedStartOffset])

	// B. 写入新种子
	write7BitEncodedInt(newBuf, len(targetSeed))
	newBuf.WriteString(targetSeed)

	// C. 写入新 Hash
	newHash := getDotNetHashCode(targetSeed)
	if err := binary.Write(newBuf, binary.LittleEndian, newHash); err != nil {
		panic(err)
	}
	fmt.Printf("[Patcher] New Hash Calculated: %d (0x%X)\n", newHash, newHash)

	// D. 写入剩余数据
	newBuf.Write(restData)

	if err := os.WriteFile(fwlPath, newBuf.Bytes(), 0644); err != nil {
		panic(err)
	}
	fmt.Println("[Patcher] ✅ FWL file updated successfully.")

	if _, err := os.Stat(dbPath); err == nil {
		if err := os.Remove(dbPath); err != nil {
			fmt.Printf("[Patcher] ❌ Error deleting DB file: %v\n", err)
			os.Exit(1)
		} else {
			fmt.Println("[Patcher] ♻️  Old DB file deleted. World will regenerate on startup.")
		}
	} else {
		fmt.Println("[Patcher] DB file not found, skipping deletion.")
	}
}