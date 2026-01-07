package com.imparse.demo.ui

import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.imparse.demo.databinding.ActivityMessageDetailBinding
import com.imparse.demo.data.Message
import com.imparse.demo.utils.MessageDataGenerator
import com.imparse.models.StyleConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MessageDetailActivity : AppCompatActivity() {
    
    private lateinit var binding: ActivityMessageDetailBinding
    private lateinit var adapter: MessageAdapter
    private var messages: List<Message> = emptyList()
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMessageDetailBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.title = "消息详情"
        
        // 测试 StyleConfig 是否正确读取新字段
        testStyleConfig()
        
        setupRecyclerView()
        loadMessages()
    }
    
    override fun onSupportNavigateUp(): Boolean {
        onBackPressed()
        return true
    }
    
    private fun testStyleConfig() {
        Log.d("StyleConfigTest", "========== 测试 StyleConfig ==========")
        
        // 测试默认配置
        val defaultConfig = StyleConfig.default()
        if (defaultConfig != null) {
            Log.d("StyleConfigTest", "✅ 成功获取默认配置")
            Log.d("StyleConfigTest", "toolbarHeight = ${defaultConfig.toolbarHeight}")
            Log.d("StyleConfigTest", "toolbarWidth = ${defaultConfig.toolbarWidth}")
            Log.d("StyleConfigTest", "toolbarPadding = ${defaultConfig.toolbarPadding}")
            Log.d("StyleConfigTest", "toolbarButtonSize = ${defaultConfig.toolbarButtonSize}")
            Log.d("StyleConfigTest", "toolbarButtonSpacing = ${defaultConfig.toolbarButtonSpacing}")
            Log.d("StyleConfigTest", "toolbarSwitcherHeight = ${defaultConfig.toolbarSwitcherHeight}")
            Log.d("StyleConfigTest", "toolbarSwitcherButtonWidth = ${defaultConfig.toolbarSwitcherButtonWidth}")
            Log.d("StyleConfigTest", "toolbarSwitcherButtonSpacing = ${defaultConfig.toolbarSwitcherButtonSpacing}")
            Log.d("StyleConfigTest", "tableTitle = ${defaultConfig.tableTitle}")
            Log.d("StyleConfigTest", "toolbarPreviewText = ${defaultConfig.toolbarPreviewText}")
            Log.d("StyleConfigTest", "toolbarCodeText = ${defaultConfig.toolbarCodeText}")
            
            // 打印完整 JSON
            Log.d("StyleConfigTest", "完整 JSON:")
            Log.d("StyleConfigTest", defaultConfig.toJSON())
        } else {
            Log.e("StyleConfigTest", "❌ 获取默认配置失败")
        }
        
        Log.d("StyleConfigTest", "====================================")
    }
    
    /**
     * 计算内容宽度：屏幕宽度 - 左右边距（32dp * 2 = 64dp）
     */
    private fun calculateContentWidth(): Int {
        val screenWidth = resources.displayMetrics.widthPixels
        val marginDp = 64
        val marginPx = (marginDp * resources.displayMetrics.density).toInt()
        return screenWidth - marginPx
    }
    
    private fun setupRecyclerView() {
        binding.recyclerView.layoutManager = LinearLayoutManager(this)
        
        val contentWidth = calculateContentWidth()
        adapter = MessageAdapter(emptyList(), contentWidth, this)
        binding.recyclerView.adapter = adapter
    }
    
    private fun loadMessages() {
        lifecycleScope.launch(Dispatchers.IO) {
            // 生成消息
            val generatedMessages = MessageDataGenerator.generateMessages(count = 18)
            
            // 在后台线程解析消息
            val parsedMessages = generatedMessages.map { message ->
                message.parse()
                message
            }
            
            // 回到主线程更新 UI
            withContext(Dispatchers.Main) {
                messages = parsedMessages
                // 只需要更新 adapter 的数据，不需要重新创建 adapter
                adapter.submitList(messages)
            }
        }
    }
}

