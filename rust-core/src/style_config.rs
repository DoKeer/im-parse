use serde::{Deserialize, Serialize};

/// 样式配置
/// 所有平台共享的样式配置，用于统一控制渲染样式
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StyleConfig {
    /// 基础字体大小（px）
    #[serde(default = "default_font_size")]
    pub font_size: f32,
    
    /// 代码字体大小（px）
    #[serde(default = "default_code_font_size")]
    pub code_font_size: f32,
    
    /// 文本颜色（十六进制，如 "#333333"）
    #[serde(default = "default_text_color")]
    pub text_color: String,
    
    /// 背景颜色（十六进制，如 "#ffffff"）
    #[serde(default = "default_background_color")]
    pub background_color: String,
    
    /// 链接颜色（十六进制，如 "#007AFF"）
    #[serde(default = "default_link_color")]
    pub link_color: String,
    
    /// 代码背景颜色（十六进制，如 "#f4f4f4"）
    #[serde(default = "default_code_background_color")]
    pub code_background_color: String,
    
    /// 代码文本颜色（十六进制）
    #[serde(default = "default_code_text_color")]
    pub code_text_color: String,
    
    /// 标题颜色数组（h1-h6，十六进制）
    #[serde(default = "default_heading_colors")]
    pub heading_colors: Vec<String>,
    
    /// 段落间距（px）
    #[serde(default = "default_paragraph_spacing")]
    pub paragraph_spacing: f32,
    
    /// 列表项间距（px）
    #[serde(default = "default_list_item_spacing")]
    pub list_item_spacing: f32,
    
    /// 代码块内边距（px）
    #[serde(default = "default_code_block_padding")]
    pub code_block_padding: f32,
    
    /// 代码块圆角（px）
    #[serde(default = "default_code_block_border_radius")]
    pub code_block_border_radius: f32,
    
    /// 表格单元格内边距（px）
    #[serde(default = "default_table_cell_padding")]
    pub table_cell_padding: f32,
    
    /// 表格边框颜色（十六进制）
    #[serde(default = "default_table_border_color")]
    pub table_border_color: String,
    
    /// 表格表头背景颜色（十六进制）
    #[serde(default = "default_table_header_background")]
    pub table_header_background: String,
    
    /// 引用块左边框宽度（px）
    #[serde(default = "default_blockquote_border_width")]
    pub blockquote_border_width: f32,
    
    /// 引用块左边框颜色（十六进制）
    #[serde(default = "default_blockquote_border_color")]
    pub blockquote_border_color: String,
    
    /// 引用块文本颜色（十六进制）
    #[serde(default = "default_blockquote_text_color")]
    pub blockquote_text_color: String,
    
    /// 图片圆角（px）
    #[serde(default = "default_image_border_radius")]
    pub image_border_radius: f32,
    
    /// 图片外边距（px）
    #[serde(default = "default_image_margin")]
    pub image_margin: f32,
    
    /// 提及背景颜色（十六进制）
    #[serde(default = "default_mention_background")]
    pub mention_background: String,
    
    /// 提及文本颜色（十六进制）
    #[serde(default = "default_mention_text_color")]
    pub mention_text_color: String,
    
    /// 卡片背景颜色（十六进制）
    #[serde(default = "default_card_background")]
    pub card_background: String,
    
    /// 卡片边框颜色（十六进制）
    #[serde(default = "default_card_border_color")]
    pub card_border_color: String,
    
    /// 卡片内边距（px）
    #[serde(default = "default_card_padding")]
    pub card_padding: f32,
    
    /// 卡片圆角（px）
    #[serde(default = "default_card_border_radius")]
    pub card_border_radius: f32,
    
    /// 水平分割线颜色（十六进制）
    #[serde(default = "default_hr_color")]
    pub hr_color: String,
    
    /// 行高倍数
    #[serde(default = "default_line_height")]
    pub line_height: f32,
    
    /// 内容最大宽度（px，0 表示不限制）
    #[serde(default = "default_max_content_width")]
    pub max_content_width: f32,
    
    /// 内容内边距（px）
    #[serde(default = "default_content_padding")]
    pub content_padding: f32,
}

impl Default for StyleConfig {
    fn default() -> Self {
        Self {
            font_size: default_font_size(),
            code_font_size: default_code_font_size(),
            text_color: default_text_color(),
            background_color: default_background_color(),
            link_color: default_link_color(),
            code_background_color: default_code_background_color(),
            code_text_color: default_code_text_color(),
            heading_colors: default_heading_colors(),
            paragraph_spacing: default_paragraph_spacing(),
            list_item_spacing: default_list_item_spacing(),
            code_block_padding: default_code_block_padding(),
            code_block_border_radius: default_code_block_border_radius(),
            table_cell_padding: default_table_cell_padding(),
            table_border_color: default_table_border_color(),
            table_header_background: default_table_header_background(),
            blockquote_border_width: default_blockquote_border_width(),
            blockquote_border_color: default_blockquote_border_color(),
            blockquote_text_color: default_blockquote_text_color(),
            image_border_radius: default_image_border_radius(),
            image_margin: default_image_margin(),
            mention_background: default_mention_background(),
            mention_text_color: default_mention_text_color(),
            card_background: default_card_background(),
            card_border_color: default_card_border_color(),
            card_padding: default_card_padding(),
            card_border_radius: default_card_border_radius(),
            hr_color: default_hr_color(),
            line_height: default_line_height(),
            max_content_width: default_max_content_width(),
            content_padding: default_content_padding(),
        }
    }
}

// 默认值函数
fn default_font_size() -> f32 { 16.0 }
fn default_code_font_size() -> f32 { 14.0 }
fn default_text_color() -> String { "#333333".to_string() }
fn default_background_color() -> String { "#ffffff".to_string() }
fn default_link_color() -> String { "#007AFF".to_string() }
fn default_code_background_color() -> String { "#f4f4f4".to_string() }
fn default_code_text_color() -> String { "#333333".to_string() }
fn default_heading_colors() -> Vec<String> {
    vec![
        "#333333".to_string(),
        "#333333".to_string(),
        "#333333".to_string(),
        "#333333".to_string(),
        "#333333".to_string(),
        "#333333".to_string(),
    ]
}
fn default_paragraph_spacing() -> f32 { 16.0 }
fn default_list_item_spacing() -> f32 { 8.0 }
fn default_code_block_padding() -> f32 { 16.0 }
fn default_code_block_border_radius() -> f32 { 8.0 }
fn default_table_cell_padding() -> f32 { 8.0 }
fn default_table_border_color() -> String { "#dddddd".to_string() }
fn default_table_header_background() -> String { "#f4f4f4".to_string() }
fn default_blockquote_border_width() -> f32 { 4.0 }
fn default_blockquote_border_color() -> String { "#dddddd".to_string() }
fn default_blockquote_text_color() -> String { "#666666".to_string() }
fn default_image_border_radius() -> f32 { 8.0 }
fn default_image_margin() -> f32 { 16.0 }
fn default_mention_background() -> String { "#E3F2FD".to_string() }
fn default_mention_text_color() -> String { "#1976D2".to_string() }
fn default_card_background() -> String { "#f9f9f9".to_string() }
fn default_card_border_color() -> String { "#dddddd".to_string() }
fn default_card_padding() -> f32 { 16.0 }
fn default_card_border_radius() -> f32 { 8.0 }
fn default_hr_color() -> String { "#dddddd".to_string() }
fn default_line_height() -> f32 { 1.6 }
fn default_max_content_width() -> f32 { 800.0 }
fn default_content_padding() -> f32 { 20.0 }

impl StyleConfig {
    /// 创建深色模式配置
    pub fn dark() -> Self {
        Self {
            text_color: "#f2f2f7".to_string(),
            background_color: "#1c1c1e".to_string(),
            code_background_color: "#2c2c2e".to_string(),
            code_text_color: "#f2f2f7".to_string(),
            heading_colors: vec![
                "#f2f2f7".to_string(),
                "#f2f2f7".to_string(),
                "#f2f2f7".to_string(),
                "#f2f2f7".to_string(),
                "#f2f2f7".to_string(),
                "#f2f2f7".to_string(),
            ],
            table_border_color: "#3a3a3c".to_string(),
            table_header_background: "#2c2c2e".to_string(),
            blockquote_border_color: "#3a3a3c".to_string(),
            blockquote_text_color: "#a1a1a6".to_string(),
            mention_background: "#1e3a5f".to_string(),
            mention_text_color: "#64b5f6".to_string(),
            card_background: "#2c2c2e".to_string(),
            card_border_color: "#3a3a3c".to_string(),
            hr_color: "#3a3a3c".to_string(),
            ..Default::default()
        }
    }
}

