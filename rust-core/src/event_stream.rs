// Event Stream 封装 - 解决 Event 流控制分散问题
// 
// 设计目标：
// 1. 集中式 Event 消费控制
// 2. 显式的状态追踪
// 3. 更好的错误处理

use pulldown_cmark::{Event, Tag, TagEnd};
use crate::ParseError;

/// Event 流封装器
/// 
/// 职责：
/// - 集中管理 Event 的 peek/next 操作
/// - 提供结构化的消费模式（consume_until）
/// - 调试模式下追踪消费位置
pub struct EventStream<'a, I: Iterator<Item = Event<'a>>> {
    inner: std::iter::Peekable<I>,
    
    #[cfg(debug_assertions)]
    position: usize,
    
    #[cfg(debug_assertions)]
    consumed_events: Vec<EventDebugInfo>,
}

#[cfg(debug_assertions)]
#[derive(Debug, Clone)]
struct EventDebugInfo {
    position: usize,
    event_type: String,
}

impl<'a, I: Iterator<Item = Event<'a>>> EventStream<'a, I> {
    pub fn new(iter: I) -> Self {
        Self {
            inner: iter.peekable(),
            
            #[cfg(debug_assertions)]
            position: 0,
            
            #[cfg(debug_assertions)]
            consumed_events: Vec::new(),
        }
    }
    
    /// 查看下一个事件但不消费
    pub fn peek(&mut self) -> Option<&Event<'a>> {
        self.inner.peek()
    }
    
    /// 消费下一个事件
    pub fn next(&mut self) -> Option<Event<'a>> {
        let event = self.inner.next();
        
        #[cfg(debug_assertions)]
        {
            if let Some(ref e) = event {
                self.consumed_events.push(EventDebugInfo {
                    position: self.position,
                    event_type: format!("{:?}", std::mem::discriminant(e)),
                });
                self.position += 1;
            }
        }
        
        event
    }
    
    /// 消费事件直到满足条件
    /// 
    /// # 参数
    /// - `matcher`: 匹配函数，返回 true 时停止消费（不消费匹配的事件）
    /// 
    /// # 返回
    /// 消费的事件列表（不包括匹配的终止事件）
    pub fn consume_until<F>(&mut self, matcher: F) -> Vec<Event<'a>>
    where
        F: Fn(&Event<'a>) -> bool,
    {
        let mut events = Vec::new();
        
        while let Some(event) = self.peek() {
            if matcher(event) {
                break;
            }
            // 这里必须消费事件（已经检查过了）
            events.push(self.next().unwrap());
        }
        
        events
    }
    
    /// 消费事件直到遇到特定的结束标记
    /// 
    /// # 参数
    /// - `expected_end`: 期望的结束标记
    /// 
    /// # 返回
    /// - Ok(events): 成功消费，返回事件列表（不包括结束标记）
    /// - Err: 遇到意外的事件或流结束
    pub fn consume_until_end(&mut self, expected_end: TagEnd) -> Result<Vec<Event<'a>>, ParseError> {
        let events = self.consume_until(|e| {
            matches!(e, Event::End(tag) if *tag == expected_end)
        });
        
        // 验证并消费结束标记
        match self.next() {
            Some(Event::End(tag)) if tag == expected_end => Ok(events),
            Some(other) => Err(ParseError::UnexpectedEvent(format!(
                "Expected {:?}, got {:?}",
                expected_end, other
            ))),
            None => Err(ParseError::UnexpectedEnd(format!(
                "Expected {:?}, but stream ended",
                expected_end
            ))),
        }
    }
    
    /// 期望并消费特定的结束标记
    pub fn expect_end(&mut self, expected: TagEnd) -> Result<(), ParseError> {
        match self.next() {
            Some(Event::End(tag)) if tag == expected => Ok(()),
            Some(other) => Err(ParseError::UnexpectedEvent(format!(
                "Expected End({:?}), got {:?}",
                expected, other
            ))),
            None => Err(ParseError::UnexpectedEnd(format!(
                "Expected End({:?}), but stream ended",
                expected
            ))),
        }
    }
    
    /// 检查是否还有更多事件
    pub fn has_more(&mut self) -> bool {
        self.peek().is_some()
    }
    
    /// 调试：打印消费历史
    #[cfg(debug_assertions)]
    pub fn dump_consumed_events(&self) {
        eprintln!("=== Consumed Events ({} total) ===", self.consumed_events.len());
        for info in &self.consumed_events {
            eprintln!("  [{}] {}", info.position, info.event_type);
        }
    }
}

/// Event 匹配器辅助函数
pub mod matchers {
    use super::*;
    
    /// 匹配任意段落结束
    pub fn is_paragraph_end(event: &Event) -> bool {
        matches!(event, Event::End(TagEnd::Paragraph))
    }
    
    /// 匹配任意标题结束
    pub fn is_heading_end(event: &Event) -> bool {
        matches!(event, Event::End(TagEnd::Heading(_)))
    }
    
    /// 匹配任意表格单元格结束
    pub fn is_table_cell_end(event: &Event) -> bool {
        matches!(event, Event::End(TagEnd::TableCell))
    }
    
    /// 匹配任意列表项结束
    pub fn is_list_item_end(event: &Event) -> bool {
        matches!(event, Event::End(TagEnd::Item))
    }
    
    /// 匹配任意引用块结束
    pub fn is_blockquote_end(event: &Event) -> bool {
        matches!(event, Event::End(TagEnd::BlockQuote(_)))
    }
    
    /// 匹配任意列表结束
    pub fn is_list_end(event: &Event) -> bool {
        matches!(event, Event::End(TagEnd::List(_)))
    }
    
    /// 匹配行内内容的边界（段落/标题/单元格/列表项结束）
    pub fn is_inline_context_boundary(event: &Event) -> bool {
        matches!(event,
            Event::End(TagEnd::Paragraph)
            | Event::End(TagEnd::Heading(_))
            | Event::End(TagEnd::TableCell)
            | Event::End(TagEnd::Item)
        )
    }
    
    /// 匹配块级内容的开始（不应在行内出现）
    pub fn is_block_level_start(event: &Event) -> bool {
        matches!(event,
            Event::Start(Tag::Paragraph)
            | Event::Start(Tag::Heading { .. })
            | Event::Start(Tag::BlockQuote(_))
            | Event::Start(Tag::List(_))
            | Event::Start(Tag::CodeBlock(_))
            | Event::Start(Tag::Table(_))
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use pulldown_cmark::{Parser, Options, HeadingLevel};
    
    #[test]
    fn test_consume_until() {
        let markdown = "**bold** text";
        let parser = Parser::new(markdown);
        let mut stream = EventStream::new(parser);
        
        // 消费直到段落结束
        let events = stream.consume_until(matchers::is_paragraph_end);
        assert!(!events.is_empty());
        
        // 确认下一个是段落结束
        assert!(matches!(stream.peek(), Some(Event::End(TagEnd::Paragraph))));
    }
    
    #[test]
    fn test_consume_until_end() {
        let markdown = "**bold**";
        let parser = Parser::new(markdown);
        let mut stream = EventStream::new(parser);
        
        // 跳过 Start(Paragraph)
        stream.next();
        
        // 跳过 Start(Strong)
        stream.next();
        
        // 消费直到 Strong 结束
        let result = stream.consume_until_end(TagEnd::Strong);
        assert!(result.is_ok());
        
        let events = result.unwrap();
        assert_eq!(events.len(), 1);
        assert!(matches!(events[0], Event::Text(_)));
    }
    
    #[test]
    fn test_expect_end_success() {
        let markdown = "text";
        let parser = Parser::new(markdown);
        let mut stream = EventStream::new(parser);
        
        // Start(Paragraph)
        stream.next();
        // Text
        stream.next();
        
        // 期望 End(Paragraph)
        assert!(stream.expect_end(TagEnd::Paragraph).is_ok());
    }
    
    #[test]
    fn test_expect_end_failure() {
        let markdown = "text";
        let parser = Parser::new(markdown);
        let mut stream = EventStream::new(parser);
        
        // Start(Paragraph)
        stream.next();
        
        // 期望错误的结束标记
        assert!(stream.expect_end(TagEnd::Heading(HeadingLevel::H1)).is_err());
    }
}

