/// Project portfolio data models and sample showcase projects.
library;

/// Represents a featured portfolio project.
class PortfolioProject {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String imageAlt;
  final List<String> tags;
  final String? demoUrl;
  final String githubUrl;
  final String category;

  const PortfolioProject({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.imageAlt,
    required this.tags,
    this.demoUrl,
    required this.githubUrl,
    required this.category,
  });
}

/// Six featured engineering projects showcasing distributed systems,
/// reactive frontend architecture, and compiler engineering.
final List<PortfolioProject> featuredProjects = [
  const PortfolioProject(
    id: 'aether-kv',
    title: 'AetherKV — Distributed Multi-Raft Store',
    description:
        'A high-throughput, horizontally partitioned key-value database implementing Multi-Raft consensus with LSM-tree storage engines and sub-millisecond p99 latency.',
    imageUrl:
        'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=800&auto=format&fit=crop&q=80',
    imageAlt: 'Server rack lights illuminating a modern datacenter corridor',
    tags: ['Rust', 'Raft Consensus', 'LSM-Tree', 'gRPC', 'Distributed Systems'],
    demoUrl: 'https://aetherkv-bench.demo.dev',
    githubUrl: 'https://github.com/alexrivera-dev/aether-kv',
    category: 'Distributed Systems',
  ),
  const PortfolioProject(
    id: 'prism-flow',
    title: 'PrismFlow — Real-Time Signal Stream Engine',
    description:
        'Ultra-low-latency real-time data streaming platform processing 2.5M telemetry events/sec with reactive backpressure and WebAssembly user-defined filters.',
    imageUrl:
        'https://images.unsplash.com/photo-1504639725590-34d0984388bd?w=800&auto=format&fit=crop&q=80',
    imageAlt: 'Abstract glowing network streams and digital telemetry data visualization',
    tags: ['Dart', 'WebAssembly', 'WebSockets', 'Signals', 'Zero-Copy'],
    demoUrl: 'https://prismflow.demo.dev',
    githubUrl: 'https://github.com/alexrivera-dev/prism-flow',
    category: 'Real-Time Streaming',
  ),
  const PortfolioProject(
    id: 'vector-loom',
    title: 'VectorLoom — In-Memory HNSW Vector Index',
    description:
        'High-dimensional similarity search engine optimized for AI embedding retrieval with SIMD AVX-512 distance calculations and incremental index merging.',
    imageUrl:
        'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&auto=format&fit=crop&q=80',
    imageAlt: 'Topological geometric vector mesh rendered in iridescent violet gradients',
    tags: ['C++', 'SIMD', 'HNSW', 'AI Embeddings', 'Memory Architecture'],
    demoUrl: 'https://vectorloom.demo.dev',
    githubUrl: 'https://github.com/alexrivera-dev/vector-loom',
    category: 'Vector Search / AI',
  ),
  const PortfolioProject(
    id: 'bloom-native-ui',
    title: 'Bloom JS Native — Fine-Grained Reactive Framework',
    description:
        'Pure Dart to JavaScript web framework compiling reactive AST descriptors to DOM nodes with zero virtual DOM overhead and sub-millisecond SSR.',
    imageUrl:
        'https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=800&auto=format&fit=crop&q=80',
    imageAlt: 'Clean lines of code on an ultra-wide dark mode monitor',
    tags: ['Dart', 'AST Compiler', 'Signals', 'DOM Interop', 'WASM Ready'],
    demoUrl: 'https://bloom-framework.dev',
    githubUrl: 'https://github.com/Chidi09/Bloom',
    category: 'Web Architecture',
  ),
  const PortfolioProject(
    id: 'helix-mesh',
    title: 'HelixMesh — Zero-Trust Edge Service Proxy',
    description:
        'Programmable eBPF-powered Layer 7 edge gateway with automatic mTLS, distributed rate limiting, and dynamic traffic canary routing.',
    imageUrl:
        'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=800&auto=format&fit=crop&q=80',
    imageAlt: 'Cybersecurity matrix with digital encryption nodes and dark neon lines',
    tags: ['Go', 'eBPF', 'mTLS', 'Kubernetes', 'Envoy Protocol'],
    demoUrl: 'https://helixmesh.demo.dev',
    githubUrl: 'https://github.com/alexrivera-dev/helix-mesh',
    category: 'Cloud Infrastructure',
  ),
  const PortfolioProject(
    id: 'chronos-db',
    title: 'Chronos — High-Compression Time Series DB',
    description:
        'Columnar time-series storage engine utilizing Gorilla delta-of-delta timestamp encoding and Zstandard chunk compression for IoT telemetry.',
    imageUrl:
        'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&auto=format&fit=crop&q=80',
    imageAlt: 'Microchip circuit traces illuminated with warm copper glow',
    tags: ['Rust', 'Gorilla Compression', 'Columnar Format', 'IoT Telemetry'],
    demoUrl: 'https://chronos-db.demo.dev',
    githubUrl: 'https://github.com/alexrivera-dev/chronos-db',
    category: 'Storage Engines',
  ),
];
