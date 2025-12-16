package com.imparse.demo.ui

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.imparse.demo.databinding.ActivityMainBinding
import com.imparse.demo.data.Message
import com.imparse.demo.utils.MessageDataGenerator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : AppCompatActivity() {
    
    private lateinit var binding: ActivityMainBinding
    private lateinit var adapter: MessageAdapter
    private var messages: List<Message> = emptyList()
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        setupRecyclerView()
        loadMessages()
    }
    
    private fun setupRecyclerView() {
        binding.recyclerView.layoutManager = LinearLayoutManager(this)
        
        // 计算内容宽度：屏幕宽度 - 左右边距（32dp * 2 = 64dp）
        val screenWidth = resources.displayMetrics.widthPixels
        val marginDp = 64
        val marginPx = (marginDp * resources.displayMetrics.density).toInt()
        val contentWidth = screenWidth - marginPx
        
        adapter = MessageAdapter(emptyList(), contentWidth, this)
        binding.recyclerView.adapter = adapter
    }
    
    private fun loadMessages() {
        lifecycleScope.launch(Dispatchers.IO) {
            // 生成消息
            val generatedMessages = MessageDataGenerator.generateMessages(count = 5)
            
            // 在后台线程解析消息
            val parsedMessages = generatedMessages.map { message ->
                message.parse()
                message
            }
            
            // 回到主线程更新 UI
            withContext(Dispatchers.Main) {
                messages = parsedMessages
                val screenWidth = resources.displayMetrics.widthPixels
                val marginDp = 64
                val marginPx = (marginDp * resources.displayMetrics.density).toInt()
                val contentWidth = screenWidth - marginPx
                adapter = MessageAdapter(messages, contentWidth, this@MainActivity)
                binding.recyclerView.adapter = adapter
            }
        }
    }
}

