#!/bin/bash

GAIA_API_KEY="your_gaia_api_key"  # Ganti dengan API key yang benar
API_URL="https://your_gaia_domains/v1/chat/completions"
QUESTION_FILE="questions.txt"

# Periksa apakah file pertanyaan ada
if [[ ! -f "$QUESTION_FILE" ]]; then
    echo "❌ Error: File $QUESTION_FILE tidak ditemukan!"
    exit 1
fi

SESSION_COUNT=0  # Hitungan sesi pengulangan

# Loop tanpa batas agar terus mengulang
while true; do
    SESSION_COUNT=$((SESSION_COUNT + 1))
    SUCCESS_COUNT=0
    FAILED_COUNT=0
    QUESTION_INDEX=0
    TOTAL_QUESTIONS=$(wc -l < "$QUESTION_FILE")  # Hitung jumlah pertanyaan

    echo "🏁 Memulai sesi ke-$SESSION_COUNT dari $TOTAL_QUESTIONS pertanyaan..."
    echo "=========================================="

    while IFS= read -r question; do
        QUESTION_INDEX=$((QUESTION_INDEX + 1))
        echo "📝 Pertanyaan ($QUESTION_INDEX/$TOTAL_QUESTIONS): $question"

        # Kirim request dan simpan response serta status kode
        RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
            -H "Authorization: Bearer $GAIA_API_KEY" \
            -H "accept: application/json" \
            -H "Content-Type: application/json" \
            -d "{\"messages\":[{\"role\":\"system\", \"content\": \"You are a helpful assistant.\"}, {\"role\":\"user\", \"content\": \"$question\"}]}")

        # Pisahkan body response dan status kode
        HTTP_BODY=$(echo "$RESPONSE" | sed '$d')   # Semua kecuali baris terakhir
        HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)  # Baris terakhir adalah status kode

        # Cek apakah response mengandung jawaban
        ANSWER=$(echo "$HTTP_BODY" | grep -o '"content":"[^"]*"' | cut -d':' -f2- | tr -d '"')

        # Handle berbagai kemungkinan status kode
        case $HTTP_CODE in
            200)
                if [[ -n "$ANSWER" ]]; then
                    echo "💬 Jawaban: $ANSWER"
                    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                else
                    echo "❌ Tidak ada jawaban dalam response."
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                fi
                ;;
            400)
                echo "❌ Error 400: Bad request."
                FAILED_COUNT=$((FAILED_COUNT + 1))
                ;;
            404)
                echo "❌ Error 404: Endpoint tidak ditemukan."
                FAILED_COUNT=$((FAILED_COUNT + 1))
                ;;
            500)
                echo "❌ Error 500: Internal Server Error."
                FAILED_COUNT=$((FAILED_COUNT + 1))
                ;;
            *)
                echo "❌ Error $HTTP_CODE: Terjadi kesalahan yang tidak diketahui."
                FAILED_COUNT=$((FAILED_COUNT + 1))
                ;;
        esac

        echo ""  # Baris kosong sebagai pemisah output
        
        # Hitungan mundur 10 detik sebelum pertanyaan berikutnya
        if [[ $QUESTION_INDEX -lt $TOTAL_QUESTIONS ]]; then
            for ((i=10; i>0; i--)); do
                echo -ne "\r⏳ Mohon tunggu pertanyaan berikutnya dalam $i detik..."  # Tambah spasi ekstra di akhir
                sleep 1
            done
            echo -ne "\r\033[K"  # Hapus baris setelah countdown selesai
            echo "📝 Pertanyaan berikutnya..."
        fi

    done < "$QUESTION_FILE"

    # Tampilkan ringkasan sesi
    echo "=========================================="
    echo "🏁 Sesi ke-$SESSION_COUNT selesai!"
    echo "✅ Total pertanyaan berhasil dijawab: $SUCCESS_COUNT"
    echo "❌ Total pertanyaan gagal dijawab: $FAILED_COUNT"
    echo "=========================================="

    echo ""

    for ((i=5; i>0; i--)); do
        echo -ne "\r🔄 Mengulang dari awal dalam $i detik..."  # Tambah spasi ekstra di akhir
        sleep 1
    done # Jeda sebelum mengulang kembali
    
    echo -ne ""
done
