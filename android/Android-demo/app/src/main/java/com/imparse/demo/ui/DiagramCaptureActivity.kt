package com.imparse.demo.ui

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.util.Base64
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.imparse.demo.databinding.ActivityDiagramCaptureBinding

class DiagramCaptureActivity : AppCompatActivity() {

    private lateinit var binding: ActivityDiagramCaptureBinding
    private lateinit var webView: WebView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityDiagramCaptureBinding.inflate(layoutInflater)
        setContentView(binding.root)

        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.title = "Diagram Export (Production)"

        webView = binding.webView
        setupWebView()
        loadHtml()
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }

    // ------------------------
    // WebView setup
    // ------------------------

    private fun setupWebView() {
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            useWideViewPort = true
            loadWithOverviewMode = true
            builtInZoomControls = false
            displayZoomControls = false
        }

        webView.addJavascriptInterface(WebBridge(), "AndroidBridge")

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                // 页面加载完成后，确保 JavaScript 接口可用
                view?.evaluateJavascript("""
                    if (typeof AndroidBridge !== 'undefined') {
                        console.log('AndroidBridge is ready');
                    } else {
                        console.error('AndroidBridge is not available');
                    }
                """.trimIndent(), null)
            }
        }

        webView.webChromeClient = WebChromeClient()
    }

    // ------------------------
    // HTML + JS
    // ------------------------

    private fun loadHtml() {
        // Mermaid 代码
        val mermaidCode = """
graph TD;
  A[开始] --> B[处理];
  A --> C[验证];
  B --> D[完成];
  C --> D;
        """.trimIndent()
        
        // 检测是否为 Gantt 图表
        val isGantt = mermaidCode.trim().lowercase().startsWith("gantt")
        
        // Gantt 图表的特殊 CSS 样式
        val ganttCSS = if (isGantt) {
            """
                .mermaid {
                    width: 100%;
                    overflow-x: auto;
                    overflow-y: visible;
                }
                .mermaid svg {
                    width: 100% !important;
                    max-width: 100% !important;
                    min-width: 1400px !important;
                }
            """.trimIndent()
        } else {
            """
                /* 非 Gantt 图表：保持自然大小，居中显示 */
                .mermaid {
                    display: inline-block;
                    max-width: 100%;
                    text-align: center;
                }
                .mermaid svg {
                    display: block;
                    margin: 0 auto;
                    max-width: 100%;
                    height: auto;
                }
            """.trimIndent()
        }
        
        val ganttLog = if (isGantt) "console.log('Gantt chart detected');" else ""
        
        val html = """
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>

<script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
<script src="https://cdn.jsdelivr.net/npm/mermaid@8.13.0/dist/mermaid.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js"></script>

<style>
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}
body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #FFFFFF;
    margin: 0;
    padding: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    width: 100%;
    overflow-x: auto;
}
.block {
    margin: 24px 0;
    padding: 16px;
    background: #f5f5f5;
    border-radius: 8px;
}
.mermaid {
    color: #000000;
}
$ganttCSS
</style>
</head>

<body>

<div id="math-container" class="block">
$${'$'}E = mc^2$$
</div>

<div id="mermaid-container" class="block mermaid">
${mermaidCode.replace("<", "&lt;").replace(">", "&gt;")}
</div>

<script>
/**
 * 精确 DOM 截图（使用 html2canvas）
 */
function captureDom(selector, name) {
    console.log('captureDom called:', selector, name);
    
    // 检查 AndroidBridge 是否可用
    if (typeof AndroidBridge === 'undefined') {
        console.error('AndroidBridge is not available');
        setTimeout(function() {
            if (typeof AndroidBridge !== 'undefined') {
                captureDom(selector, name);
            } else {
                console.error('AndroidBridge still not available after retry');
            }
        }, 100);
        return;
    }
    
    const el = document.querySelector(selector);
    if (!el) {
        console.error('Element not found:', selector);
        AndroidBridge.onCaptureError(name, "element not found: " + selector);
        return;
    }

    // 等待元素渲染完成
    setTimeout(function() {
        // 检查 html2canvas 是否已加载
        if (typeof html2canvas === 'undefined') {
            console.warn('html2canvas not loaded yet, retrying...');
            setTimeout(function() {
                captureDom(selector, name);
            }, 500);
        return;
    }

    const rect = el.getBoundingClientRect();
        console.log('Element rect:', rect);
        
        if (rect.width === 0 || rect.height === 0) {
            AndroidBridge.onCaptureError(name, "element has zero size");
            return;
        }

        // 使用 html2canvas 截图
        html2canvas(el, {
            backgroundColor: '#FFFFFF',
            scale: window.devicePixelRatio || 2,
            useCORS: true,
            logging: false,
            width: rect.width,
            height: rect.height
        }).then(function(canvas) {
    const dataUrl = canvas.toDataURL("image/png");
            console.log('Capture success, dataUrl length:', dataUrl.length);
            if (dataUrl && dataUrl.length > 100) {
    AndroidBridge.onCaptureSuccess(name, dataUrl);
            } else {
                AndroidBridge.onCaptureError(name, "invalid dataUrl");
            }
        }).catch(function(error) {
            console.error('html2canvas error:', error);
            AndroidBridge.onCaptureError(name, "html2canvas error: " + (error.message || String(error)));
        });
    }, 100);
}

/* ---------- MathJax ---------- */

window.MathJax = {
  startup: {
    ready: () => {
      MathJax.startup.defaultReady();
      console.log('MathJax ready');
      // 等待 MathJax 渲染完成
      setTimeout(() => {
        // 检查是否已渲染
        const mathElement = document.querySelector("#math-container .MathJax");
        if (mathElement) {
          console.log('MathJax element found');
          captureDom("#math-container", "math");
        } else {
          console.warn('MathJax element not found, trying anyway');
      setTimeout(() => {
        captureDom("#math-container", "math");
          }, 500);
        }
      }, 300);
    }
  }
};

/* ---------- Mermaid ---------- */

function initMermaid() {
    if (typeof mermaid !== 'undefined') {
        console.log('Initializing Mermaid...');
        var config = {
  startOnLoad: true,
            theme: 'default',
            themeVariables: {
                primaryColor: '#000000',
                primaryTextColor: '#000000',
                primaryBorderColor: '#000000',
                lineColor: '#000000',
                secondaryColor: '#FFFFFF',
                tertiaryColor: '#FFFFFF'
            }
        };
        
        $ganttLog
        
        mermaid.initialize(config);
        console.log('Mermaid initialized successfully');
        
        // 等待 Mermaid 渲染完成
        const checkMermaid = setInterval(function() {
            const svg = document.querySelector("#mermaid-container svg");
            if (svg) {
                clearInterval(checkMermaid);
    setTimeout(() => {
                    captureDom("#mermaid-container", "mermaid");
                }, 200);
            }
    }, 100);
        
        // 超时处理
        setTimeout(function() {
            clearInterval(checkMermaid);
            const svg = document.querySelector("#mermaid-container svg");
            if (svg) {
                captureDom("#mermaid-container", "mermaid");
            } else {
                AndroidBridge.onCaptureError("mermaid", "mermaid render timeout");
            }
        }, 5000);
    } else {
        console.error('Mermaid is not defined');
        // 如果 Mermaid 还没加载，等待一下再重试
        setTimeout(initMermaid, 100);
    }
}

// 页面加载完成后初始化 Mermaid
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initMermaid);
} else {
    initMermaid();
}
</script>

</body>
</html>
"""
        webView.loadDataWithBaseURL(
            "https://cdn.jsdelivr.net",
            html,
            "text/html",
            "UTF-8",
            null
        )
    }

    // ------------------------
    // JS → Android Bridge
    // ------------------------

    inner class WebBridge {

        @JavascriptInterface
        fun onCaptureSuccess(name: String, dataUrl: String) {
            android.util.Log.d("WebBridge", "onCaptureSuccess called: name=$name, dataUrl length=${dataUrl.length}")
            runOnUiThread {
                try {
                    if (dataUrl.isEmpty() || !dataUrl.startsWith("data:image")) {
                        onCaptureError(name, "invalid dataUrl format")
                        return@runOnUiThread
                    }
                    
                    val base64 = dataUrl.substringAfter("base64,")
                    if (base64.isEmpty()) {
                        onCaptureError(name, "empty base64 data")
                        return@runOnUiThread
                    }
                    
                    val bytes = Base64.decode(base64, Base64.DEFAULT)
                    val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    
                    if (bitmap == null) {
                        onCaptureError(name, "failed to decode bitmap")
                        return@runOnUiThread
                    }

                    when (name) {
                        "math" -> binding.mathImage.setImageBitmap(bitmap)
                        "mermaid" -> binding.mermaidImage.setImageBitmap(bitmap)
                    }

                    Toast.makeText(
                        this@DiagramCaptureActivity,
                        "$name 导出成功 (${bitmap.width}x${bitmap.height})",
                        Toast.LENGTH_SHORT
                    ).show()

                } catch (e: Exception) {
                    android.util.Log.e("WebBridge", "onCaptureSuccess error", e)
                    onCaptureError(name, e.message ?: "decode error")
                }
            }
        }

        @JavascriptInterface
        fun onCaptureError(name: String, msg: String) {
            android.util.Log.e("WebBridge", "onCaptureError: name=$name, msg=$msg")
            runOnUiThread {
                Toast.makeText(
                    this@DiagramCaptureActivity,
                    "$name 导出失败：$msg",
                    Toast.LENGTH_LONG
                ).show()
            }
        }
    }

    override fun onDestroy() {
        webView.destroy()
        super.onDestroy()
    }
}
