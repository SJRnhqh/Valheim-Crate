package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// read7BitEncodedInt 读取 C# 变长整数
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

// write7BitEncodedInt 写入 C# 变长整数
func write7BitEncodedInt(w *bytes.Buffer, value int) {
	v := uint32(value)
	for v >= 0x80 {
		w.WriteByte(byte(v | 0x80))
		v >>= 7
	}
	w.WriteByte(byte(v))
}

// ✅ Valheim 专用 Stable Hash 算法
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

func main() {
	if len(os.Args) < 4 {
		// 参数不足时静默退出或打印用法
		os.Exit(1)
	}

	worldName := os.Args[1]
	saveDir := os.Args[2]
	targetSeed := os.Args[3]

	// 确保存档目录存在
	localSavesPath := filepath.Join(saveDir, "worlds_local")
	fwlPath := filepath.Join(localSavesPath, worldName+".fwl")
	dbPath := filepath.Join(localSavesPath, worldName+".db")

	// 1. 【安全策略】如果文件不存在，什么都不做
	// 让服务器自己启动并生成一个标准的、带有合法 UID 的存档
	if _, err := os.Stat(fwlPath); os.IsNotExist(err) {
		fmt.Printf("[Patcher] ℹ️  FWL file not found. Skipping (Server will generate a valid one).\n")
		return
	}

	// 2. 读取现有文件
	data, err := os.ReadFile(fwlPath)
	if err != nil {
		fmt.Printf("[Patcher] ❌ Error reading file: %v\n", err)
		return
	}
	reader := bytes.NewReader(data)

	// --- 解析文件头 ---
	var version int32
	binary.Read(reader, binary.LittleEndian, &version) // Version
	reader.Seek(4, io.SeekCurrent)                    // Padding/Size

	// 读取世界名
	nameLen, _ := read7BitEncodedInt(reader)
	reader.Seek(int64(nameLen), io.SeekCurrent)

	// 记录 Header 结束位置（用于后续拼接）
	headerSize := len(data) - reader.Len()

	// 读取【现有种子】
	oldSeedLen, _ := read7BitEncodedInt(reader)
	oldSeedBytes := make([]byte, oldSeedLen)
	reader.Read(oldSeedBytes)
	currentSeed := string(oldSeedBytes)

	// 3. 【比对策略】如果种子一样，直接退出，不要折腾 DB 文件
	if currentSeed == targetSeed {
		fmt.Printf("[Patcher] ✅ Seed matches (%s). No action needed.\n", currentSeed)
		return
	}

	fmt.Printf("[Patcher] 🔧 Seed mismatch! Current: [%s] -> Target: [%s]. Patching...\n", currentSeed, targetSeed)

	// --- 智能定位 Hash ---
	// 计算旧种子原本的 Hash，用于在文件中定位它
	expectedOldHash := getValheimStableHashCode(currentSeed)
	
	// 向后扫描寻找 Hash (保留 UID 的关键步骤)
	var gapData []byte
	foundHash := false
	for i := 0; i < 128; i++ {
		currentPos, _ := reader.Seek(0, io.SeekCurrent)
		var candidateHash int32
		err := binary.Read(reader, binary.LittleEndian, &candidateHash)
		if err != nil { break }

		if candidateHash == expectedOldHash {
			foundHash = true
			break
		}
		
		// 如果不是 Hash，说明是种子和 Hash 之间的 padding（极少见但可能存在）
		reader.Seek(currentPos, io.SeekStart)
		b, _ := reader.ReadByte()
		gapData = append(gapData, b)
	}

	if !foundHash {
		fmt.Println("[Patcher] ❌ FATAL: Could not locate old Hash. File structure unknown. Aborting.")
		return 
	}

	// Hash 之后的所有数据（包含 UID、GenOptions 等）全部原样保留
	restData, _ := io.ReadAll(reader)

	// --- 4. 重组文件 (手术式修改) ---
	newBuf := new(bytes.Buffer)
	newBuf.Write(data[:headerSize])                 // A. 原样保留头部
	write7BitEncodedInt(newBuf, len(targetSeed))
	newBuf.WriteString(targetSeed)                  // B. 写入新种子字符串
	if len(gapData) > 0 {
		newBuf.Write(gapData)                       // C. 保留中间可能的 Gap
	}
	newHash := getValheimStableHashCode(targetSeed) // D. 计算并写入新 Hash
	binary.Write(newBuf, binary.LittleEndian, newHash)
	newBuf.Write(restData)                          // E. 原样保留尾部 (UID 在这里面)

	// 写入新的 .fwl
	err = os.WriteFile(fwlPath, newBuf.Bytes(), 0644)
	if err != nil {
		fmt.Printf("[Patcher] ❌ Failed to write FWL: %v\n", err)
		return
	}
	fmt.Println("[Patcher] ✅ FWL metadata updated.")

	// 5. 【删档策略】删除 .db 文件，强制游戏根据新种子重新生成地形
	if _, err := os.Stat(dbPath); err == nil {
		os.Remove(dbPath)
		fmt.Printf("[Patcher] ♻️  Deleted %s to force world regeneration.\n", filepath.Base(dbPath))
	}
}