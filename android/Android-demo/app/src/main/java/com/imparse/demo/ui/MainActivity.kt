package com.imparse.demo.ui

import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.imparse.demo.databinding.ActivityMainBinding
import com.imparse.demo.data.Message
import com.imparse.demo.utils.MessageDataGenerator
import com.imparse.models.StyleConfig
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
        
        // 测试 StyleConfig 是否正确读取新字段
        testStyleConfig()
        
        setupButtons()
    }
    
    private fun setupButtons() {
        binding.btnMessageDetail.setOnClickListener {
            val intent = android.content.Intent(this, MessageDetailActivity::class.java)
            startActivity(intent)
        }
        
        binding.btnWebViewTest.setOnClickListener {
            val intent = android.content.Intent(this, DiagramCaptureActivity::class.java)
            startActivity(intent)
        }
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

}

