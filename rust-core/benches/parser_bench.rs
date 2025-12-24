// 解析器性能基准测试
// 使用 criterion 进行精确测量

use criterion::{black_box, criterion_group, criterion_main, Criterion, BenchmarkId};
use im_parse_core::parse_markdown;

fn bench_short_text(c: &mut Criterion) {
    let input = "Hello **world** with $math$!";
    
    c.bench_function("parse_short_text_100chars", |b| {
        b.iter(|| {
            parse_markdown(black_box(input))
        });
    });
}

fn bench_medium_text(c: &mut Criterion) {
    let mut input = String::new();
    for i in 0..10 {
        input.push_str(&format!("Paragraph {} with **bold** and $math_{}$.\n\n", i, i));
    }
    
    c.bench_function("parse_medium_text_500chars", |b| {
        b.iter(|| {
            parse_markdown(black_box(&input))
        });
    });
}

fn bench_long_text(c: &mut Criterion) {
    let mut input = String::new();
    for i in 0..100 {
        input.push_str(&format!("Paragraph {} with **bold** and $math_{}$.\n\n", i, i));
    }
    
    c.bench_function("parse_long_text_5000chars", |b| {
        b.iter(|| {
            parse_markdown(black_box(&input))
        });
    });
}

fn bench_very_long_text(c: &mut Criterion) {
    let mut input = String::new();
    for i in 0..500 {
        input.push_str(&format!("Paragraph {} with **bold** and $math_{}$.\n\n", i, i));
    }
    
    c.bench_function("parse_very_long_text_25000chars", |b| {
        b.iter(|| {
            parse_markdown(black_box(&input))
        });
    });
}

fn bench_math_heavy(c: &mut Criterion) {
    let mut input = String::new();
    for i in 0..50 {
        input.push_str(&format!(
            "Formula {}: $x_{} + y_{} = z_{}$ and block:\n\n$$\\sum_{{i=0}}^n x_i = {}$$\n\n",
            i, i, i, i, i
        ));
    }
    
    c.bench_function("parse_math_heavy", |b| {
        b.iter(|| {
            parse_markdown(black_box(&input))
        });
    });
}

fn bench_table(c: &mut Criterion) {
    let input = r#"
| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| $x$ | $y$ | $z$ |
| $a$ | $b$ | $c$ |
| **bold** | *italic* | `code` |
| 1 | 2 | 3 |
"#;
    
    c.bench_function("parse_table", |b| {
        b.iter(|| {
            parse_markdown(black_box(input))
        });
    });
}

fn bench_complex_document(c: &mut Criterion) {
    let input = r#"
# Title

This is a paragraph with **bold** and *italic*.

Inline math: $E = mc^2$

Block math:

$$
\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}
$$

- List item 1
- List item 2 with $math$
- List item 3 with **bold**

## Subtitle

Another paragraph with [link](https://example.com).

> Quote with **bold** and $math$

```rust
fn main() {
    println!("Code block");
}
```

| Table | Column |
|-------|--------|
| $x$ | $y$ |
"#;
    
    c.bench_function("parse_complex_document", |b| {
        b.iter(|| {
            parse_markdown(black_box(input))
        });
    });
}

fn bench_varying_sizes(c: &mut Criterion) {
    let mut group = c.benchmark_group("varying_sizes");
    
    for size in [10, 50, 100, 500, 1000].iter() {
        let mut input = String::new();
        for i in 0..*size {
            input.push_str(&format!("Paragraph {} with **bold** and $math$.\n\n", i));
        }
        
        group.bench_with_input(
            BenchmarkId::from_parameter(size),
            &input,
            |b, input| {
                b.iter(|| parse_markdown(black_box(input)));
            },
        );
    }
    
    group.finish();
}

criterion_group!(
    benches,
    bench_short_text,
    bench_medium_text,
    bench_long_text,
    bench_very_long_text,
    bench_math_heavy,
    bench_table,
    bench_complex_document,
    bench_varying_sizes,
);

criterion_main!(benches);

