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

}

