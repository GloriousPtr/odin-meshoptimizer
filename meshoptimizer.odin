/**
* meshoptimizer - version 1.0
*
* Copyright (C) 2016-2025, by Arseny Kapoulkine (arseny.kapoulkine@gmail.com)
* Report bugs and download new versions at https://github.com/zeux/meshoptimizer
*
* This library is distributed under the MIT License. See notice at the end of this file.
*/
package meshopt

import "core:c"

_ :: c

when ODIN_OS == .Windows {
	foreign import lib "meshopt.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "meshopt.a"
} else {
	#panic("Could not find the compiled bc7e library for " + ODIN_OS)
}

/* Version macro; major * 1000 + minor * 10 + patch */
MESHOPTIMIZER_VERSION :: 1020 /* 1.2 */

// MESHOPTIMIZER_API ::

// MESHOPTIMIZER_ALLOC_CALLCONV ::

// MESHOPTIMIZER_EXPERIMENTAL :: MESHOPTIMIZER_API

/**
* Vertex attribute stream
* Each element takes size bytes, beginning at data, with stride controlling the spacing between successive elements (stride >= size).
*/
Stream :: struct {
	data:   rawptr,
	size:   c.size_t,
	stride: c.size_t,
}

/**
* Encoder options
*/
Encode_Exp_Mode :: enum c.int {
	/* When encoding exponents, use separate values for each component (maximum quality) */
	Separate,

	/* When encoding exponents, use shared value for all components of each vector (better compression) */
	SharedVector,

	/* When encoding exponents, use shared value for each component of all vectors (best compression) */
	SharedComponent,

	/* When encoding exponents, use separate values for each component, but clamp to 0 (good quality if very small values are not important) */
	Clamped,
}

/**
* Simplification options
*/
Simplify_Options :: enum c.int {
	/* Do not move vertices that are located on the topological border (vertices on triangle edges that don't have a paired triangle). Useful for simplifying portions of the larger mesh. */
	LockBorder,

	/* Improve simplification performance assuming input indices are a sparse subset of the mesh. Note that error becomes relative to subset extents. */
	Sparse,

	/* Treat error limit and resulting error as absolute instead of relative to mesh extents. */
	ErrorAbsolute,

	/* Remove disconnected parts of the mesh during simplification incrementally, regardless of the topological restrictions inside components. */
	Prune,

	/* Produce more regular triangle sizes and shapes during simplification, at some cost to geometric and attribute quality. */
	Regularize,

	/* Experimental: Allow collapses across attribute discontinuities, except for vertices that are tagged with meshopt_SimplifyVertex_Protect in vertex_lock. */
	Permissive,

	/* Produce more regular triangle sizes and shapes during simplification, at a small cost to geometric and attribute quality. */
	RegularizeLight,
}

Simplify_Options_Flags :: distinct bit_set[Simplify_Options; c.int]

/**
* Simplification vertex flags/locks, for use in `vertex_lock` arrays in simplification APIs
*/
SimplifyVertex_Lock :: 1

SimplifyVertex_Protect :: 2

SimplifyVertex_Priority :: 4

Vertex_Cache_Statistics :: struct {
	vertices_transformed: c.uint,
	warps_executed:       c.uint,
	acmr:                 f32, /* transformed vertices / triangle count; best case 0.5, worst case 3.0, optimum depends on topology */
	atvr:                 f32, /* transformed vertices / vertex count; best case 1.0, worst case 6.0, optimum is 1.0 (each vertex is transformed once) */
}

Vertex_Fetch_Statistics :: struct {
	bytes_fetched: c.uint,
	overfetch:     f32, /* fetched bytes / vertex buffer size; best case 1.0 (each byte is fetched once) */
}

Overdraw_Statistics :: struct {
	pixels_covered: c.uint,
	pixels_shaded:  c.uint,
	overdraw:       f32, /* shaded pixels / covered pixels; best case 1.0 */
}

Coverage_Statistics :: struct {
	coverage: [3]f32,
	extent:   f32, /* viewport size in mesh coordinates */
}

/**
* Meshlet is a small mesh cluster (subset) that consists of:
* - triangles, an 8-bit micro triangle (index) buffer, that for each triangle specifies three local vertices to use;
* - vertices, a 32-bit vertex indirection buffer, that for each local vertex specifies which mesh vertex to fetch vertex attributes from.
*
* For efficiency, meshlet triangles and vertices are packed into two large arrays; this structure contains offsets and counts to access the data.
*/
Meshlet :: struct {
	/* offsets within meshlet_vertices and meshlet_triangles arrays with meshlet data */
	vertex_offset: c.uint,
	triangle_offset: c.uint,

	/* number of vertices and triangles used in the meshlet; data is stored in consecutive range [offset..offset+count) for vertices and [offset..offset+count*3) for triangles */
	vertex_count: c.uint,
	triangle_count:  c.uint,
}

Bounds :: struct {
	/* bounding sphere, useful for frustum and occlusion culling */
	center: [3]f32,
	radius:         f32,

	/* normal cone, useful for backface culling */
	cone_apex: [3]f32,
	cone_axis:      [3]f32,
	cone_cutoff:    f32, /* = cos(angle/2) */

	/* normal cone axis and cutoff, stored in 8-bit SNORM format; decode using x/127.0 */
	cone_axis_s8: [3]c.schar,
	cone_cutoff_s8: c.schar,
}

/**
* Tangent generation options
*/
Tangent_Options :: enum c.int {
	Compatible,
	ZeroFallback,
}

Tangent_Options_Flags :: distinct bit_set[Tangent_Options; c.int]

@(default_calling_convention="c", link_prefix="meshopt_")
foreign lib {
	/**
	* Generates a vertex remap table from the vertex buffer and an optional index buffer and returns number of unique vertices
	* As a result, all vertices that are binary equivalent map to the same (new) location, with no gaps in the resulting sequence.
	* Resulting remap table maps old vertices to new vertices and can be used in meshopt_remapVertexBuffer/meshopt_remapIndexBuffer.
	* Note that binary equivalence considers all vertex_size bytes, including padding which should be zero-initialized.
	*
	* destination must contain enough space for the resulting remap table (vertex_count elements)
	* indices can be NULL if the input is unindexed
	*/
	generateVertexRemap :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertices: rawptr, vertex_count: c.size_t, vertex_size: c.size_t) -> c.size_t ---

	/**
	* Generates a vertex remap table from multiple vertex streams and an optional index buffer and returns number of unique vertices
	* As a result, all vertices that are binary equivalent map to the same (new) location, with no gaps in the resulting sequence.
	* Resulting remap table maps old vertices to new vertices and can be used in meshopt_remapVertexBuffer/meshopt_remapIndexBuffer.
	* To remap vertex buffers, you will need to call meshopt_remapVertexBuffer for each vertex stream.
	* Note that binary equivalence considers all size bytes in each stream, including padding which should be zero-initialized.
	*
	* destination must contain enough space for the resulting remap table (vertex_count elements)
	* indices can be NULL if the input is unindexed
	* stream_count must be <= 16
	*/
	generateVertexRemapMulti :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t, streams: ^Stream, stream_count: c.size_t) -> c.size_t ---

	/**
	* Generates a vertex remap table from the vertex buffer and an optional index buffer and returns number of unique vertices
	* As a result, all vertices that are equivalent map to the same (new) location, with no gaps in the resulting sequence.
	* Equivalence is checked in two steps: vertex positions are compared for equality, and then the user-specified equality function is called (if provided).
	* Resulting remap table maps old vertices to new vertices and can be used in meshopt_remapVertexBuffer/meshopt_remapIndexBuffer.
	*
	* destination must contain enough space for the resulting remap table (vertex_count elements)
	* indices can be NULL if the input is unindexed
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* callback can be NULL if no additional equality check is needed; otherwise, it should return 1 if vertices with specified indices are equivalent and 0 if they are not
	*/
	generateVertexRemapCustom :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, callback: proc "c" (rawptr, c.uint, c.uint) -> c.int, _context: rawptr) -> c.size_t ---

	/**
	* Generates vertex buffer from the source vertex buffer and remap table generated by meshopt_generateVertexRemap
	*
	* destination must contain enough space for the resulting vertex buffer (unique_vertex_count elements, returned by meshopt_generateVertexRemap)
	* vertex_count should be the initial vertex count and not the value returned by meshopt_generateVertexRemap
	*/
	remapVertexBuffer :: proc(destination: rawptr, vertices: rawptr, vertex_count: c.size_t, vertex_size: c.size_t, remap: ^c.uint) ---

	/**
	* Generate index buffer from the source index buffer and remap table generated by meshopt_generateVertexRemap
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	* indices can be NULL if the input is unindexed
	*/
	remapIndexBuffer :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, remap: ^c.uint) ---

	/**
	* Experimental: Filter out redundant triangles from the index buffer and return the number of remaining indices
	* Triangles are considered redundant if they are degenerate (two vertices have the same vertex key) or duplicate (matching triangle was present earlier).
	* First vertex_size bytes of every vertex are compared for equality; typically vertex_size should be set to the size of the position attribute.
	* Note that duplicate triangles with opposite windings are preserved, as they may be needed for double-sided rendering.
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	*/
	filterIndexBuffer :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertices: rawptr, vertex_count: c.size_t, vertex_size: c.size_t, vertex_stride: c.size_t) -> c.size_t ---

	/**
	* Experimental: Filter out redundant triangles from the index buffer and return the number of remaining indices
	* Triangles are considered redundant if they are degenerate (two vertices have the same vertex key) or duplicate (matching triangle was present earlier).
	* All bytes in specified streams are compared for equality; streams should include attributes relevant for position transform (e.g. bone influences).
	* Note that duplicate triangles with opposite windings are preserved, as they may be needed for double-sided rendering.
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	* stream_count must be <= 16
	*/
	filterIndexBufferMulti :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t, streams: ^Stream, stream_count: c.size_t) -> c.size_t ---

	/**
	* Generate index buffer that can be used for more efficient rendering when only a subset of the vertex attributes is necessary
	* All vertices that are binary equivalent (wrt first vertex_size bytes) map to the first vertex in the original vertex buffer.
	* This makes it possible to use the index buffer for Z pre-pass or shadowmap rendering, while using the original index buffer for regular rendering.
	* Note that binary equivalence considers all vertex_size bytes, including padding which should be zero-initialized.
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	*/
	generateShadowIndexBuffer :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertices: rawptr, vertex_count: c.size_t, vertex_size: c.size_t, vertex_stride: c.size_t) ---

	/**
	* Generate index buffer that can be used for more efficient rendering when only a subset of the vertex attributes is necessary
	* All vertices that are binary equivalent (wrt specified streams) map to the first vertex in the original vertex buffer.
	* This makes it possible to use the index buffer for Z pre-pass or shadowmap rendering, while using the original index buffer for regular rendering.
	* Note that binary equivalence considers all size bytes in each stream, including padding which should be zero-initialized.
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	* stream_count must be <= 16
	*/
	generateShadowIndexBufferMulti :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t, streams: ^Stream, stream_count: c.size_t) ---

	/**
	* Generates a remap table that maps all vertices with the same position to the same (existing) index.
	* Similarly to meshopt_generateShadowIndexBuffer, this can be helpful to pre-process meshes for position-only rendering.
	* This can also be used to implement algorithms that require positional-only connectivity, such as hierarchical simplification.
	*
	* destination must contain enough space for the resulting remap table (vertex_count elements)
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	*/
	generatePositionRemap :: proc(destination: ^c.uint, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) ---

	/**
	* Generate index buffer that can be used as a geometry shader input with triangle adjacency topology
	* Each triangle is converted into a 6-vertex patch with the following layout:
	* - 0, 2, 4: original triangle vertices
	* - 1, 3, 5: vertices adjacent to edges 02, 24 and 40
	* The resulting patch can be rendered with geometry shaders using e.g. VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST_WITH_ADJACENCY.
	* This can be used to implement algorithms like silhouette detection/expansion and other forms of GS-driven rendering.
	*
	* destination must contain enough space for the resulting index buffer (index_count*2 elements)
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	*/
	generateAdjacencyIndexBuffer :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) ---

	/**
	* Generate index buffer that can be used for PN-AEN tessellation with crack-free displacement
	* Each triangle is converted into a 12-vertex patch with the following layout:
	* - 0, 1, 2: original triangle vertices
	* - 3, 4: opposing edge for edge 0, 1
	* - 5, 6: opposing edge for edge 1, 2
	* - 7, 8: opposing edge for edge 2, 0
	* - 9, 10, 11: dominant vertices for corners 0, 1, 2
	* The resulting patch can be rendered with hardware tessellation using PN-AEN and displacement mapping.
	* See "Tessellation on Any Budget" (John McDonald, GDC 2011) for implementation details.
	*
	* destination must contain enough space for the resulting index buffer (index_count*4 elements)
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	*/
	generateTessellationIndexBuffer :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) ---

	/**
	* Generate index buffer that can be used for visibility buffer rendering and returns the size of the reorder table
	* Each triangle's provoking vertex index is equal to primitive id; this allows passing it to the fragment shader using flat/nointerpolation attribute.
	* This is important for performance on hardware where primitive id can't be accessed efficiently in fragment shader.
	* The reorder table stores the original vertex id for each vertex in the new index buffer, and should be used in the vertex shader to load vertex data.
	* The provoking vertex is assumed to be the first vertex in the triangle; if this is not the case (OpenGL), rotate each triangle (abc -> bca) before rendering.
	* For maximum efficiency the input index buffer should be optimized for vertex cache first.
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	* reorder must contain enough space for the worst case reorder table (vertex_count + index_count/3 elements)
	*/
	generateProvokingIndexBuffer :: proc(destination: ^c.uint, reorder: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t) -> c.size_t ---

	/**
	* Vertex transform cache optimizer
	* Reorders indices to reduce the number of GPU vertex shader invocations
	* If index buffer contains multiple ranges for multiple draw calls, this function needs to be called on each range individually.
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	*/
	optimizeVertexCache :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t) ---

	/**
	* Vertex transform cache optimizer for strip-like caches
	* Produces inferior results to meshopt_optimizeVertexCache from the GPU vertex cache perspective
	* However, the resulting index order is more optimal if the goal is to reduce the triangle strip length or improve compression efficiency
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	*/
	optimizeVertexCacheStrip :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t) ---

	/**
	* Vertex transform cache optimizer for FIFO caches
	* Reorders indices to reduce the number of GPU vertex shader invocations
	* Generally takes ~3x less time to optimize meshes but produces inferior results compared to meshopt_optimizeVertexCache
	* If index buffer contains multiple ranges for multiple draw calls, this function needs to be called on each range individually.
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	* cache_size should be less than the actual GPU cache size to avoid cache thrashing
	*/
	optimizeVertexCacheFifo :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t, cache_size: c.uint) ---

	/**
	* Overdraw optimizer
	* Reorders indices to reduce the number of GPU vertex shader invocations and the pixel overdraw
	* If index buffer contains multiple ranges for multiple draw calls, this function needs to be called on each range individually.
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	* indices must contain index data that is the result of meshopt_optimizeVertexCache (*not* the original mesh indices!)
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* threshold indicates how much the overdraw optimizer can degrade vertex cache efficiency (1.05 = up to 5%) to reduce overdraw more efficiently
	*/
	optimizeOverdraw :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, threshold: f32) ---

	/**
	* Vertex fetch cache optimizer
	* Reorders vertices and changes indices to reduce the amount of GPU memory fetches during vertex processing
	* Returns the number of unique vertices, which is the same as input vertex count unless some vertices are unused
	* This function works for a single vertex stream; for multiple vertex streams, use meshopt_optimizeVertexFetchRemap + meshopt_remapVertexBuffer for each stream.
	*
	* destination must contain enough space for the resulting vertex buffer (vertex_count elements)
	* indices is used both as an input and as an output index buffer
	*/
	optimizeVertexFetch :: proc(destination: rawptr, indices: ^c.uint, index_count: c.size_t, vertices: rawptr, vertex_count: c.size_t, vertex_size: c.size_t) -> c.size_t ---

	/**
	* Vertex fetch cache optimizer
	* Generates vertex remap to reduce the amount of GPU memory fetches during vertex processing
	* Returns the number of unique vertices, which is the same as input vertex count unless some vertices are unused
	* The resulting remap table should be used to reorder vertex/index buffers using meshopt_remapVertexBuffer/meshopt_remapIndexBuffer
	*
	* destination must contain enough space for the resulting remap table (vertex_count elements)
	*/
	optimizeVertexFetchRemap :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t) -> c.size_t ---

	/**
	* Index buffer encoder
	* Encodes index data into an array of bytes that is generally much smaller (<1.5 bytes/triangle) and compresses better (<1 bytes/triangle) compared to original.
	* Input index buffer must represent a triangle list.
	* Returns encoded data size on success, 0 on error; the only error condition is if buffer doesn't have enough space
	* For maximum efficiency the index buffer being encoded has to be optimized for vertex cache and vertex fetch first.
	*
	* buffer must contain enough space for the encoded index buffer (use meshopt_encodeIndexBufferBound to compute worst case size)
	*/
	encodeIndexBuffer      :: proc(buffer: ^c.uchar, buffer_size: c.size_t, indices: ^c.uint, index_count: c.size_t) -> c.size_t ---
	encodeIndexBufferBound :: proc(index_count: c.size_t, vertex_count: c.size_t) -> c.size_t ---

	/**
	* Set index encoder format version (defaults to 1)
	*
	* This function is not thread safe and must not be called concurrently with meshopt_encodeIndexBuffer/meshopt_encodeIndexSequence.
	*
	* version must specify the data format version to encode; valid values are 0 (decodable by all library versions) and 1 (decodable by 0.14+)
	*/
	encodeIndexVersion :: proc(version: c.int) ---

	/**
	* Index buffer decoder
	* Decodes index data from an array of bytes generated by meshopt_encodeIndexBuffer
	* Returns 0 if decoding was successful, and an error code otherwise
	* The decoder is safe to use for untrusted input, but it may produce garbage data (e.g. out of range indices).
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	*/
	decodeIndexBuffer :: proc(destination: rawptr, index_count: c.size_t, index_size: c.size_t, buffer: ^c.uchar, buffer_size: c.size_t) -> c.int ---

	/**
	* Get encoded index format version
	* Returns format version of the encoded index buffer/sequence, or -1 if the buffer header is invalid
	* Note that a non-negative value doesn't guarantee that the buffer will be decoded correctly if the input is malformed.
	*/
	decodeIndexVersion :: proc(buffer: ^c.uchar, buffer_size: c.size_t) -> c.int ---

	/**
	* Index sequence encoder
	* Encodes index sequence into an array of bytes that is generally smaller and compresses better compared to original.
	* Input index sequence can represent arbitrary topology; for triangle lists meshopt_encodeIndexBuffer is likely to be better.
	* Returns encoded data size on success, 0 on error; the only error condition is if buffer doesn't have enough space
	*
	* buffer must contain enough space for the encoded index sequence (use meshopt_encodeIndexSequenceBound to compute worst case size)
	*/
	encodeIndexSequence      :: proc(buffer: ^c.uchar, buffer_size: c.size_t, indices: ^c.uint, index_count: c.size_t) -> c.size_t ---
	encodeIndexSequenceBound :: proc(index_count: c.size_t, vertex_count: c.size_t) -> c.size_t ---

	/**
	* Index sequence decoder
	* Decodes index data from an array of bytes generated by meshopt_encodeIndexSequence
	* Returns 0 if decoding was successful, and an error code otherwise
	* The decoder is safe to use for untrusted input, but it may produce garbage data (e.g. out of range indices).
	*
	* destination must contain enough space for the resulting index sequence (index_count elements)
	*/
	decodeIndexSequence :: proc(destination: rawptr, index_count: c.size_t, index_size: c.size_t, buffer: ^c.uchar, buffer_size: c.size_t) -> c.int ---

	
	/**
	* Meshlet encoder
	* Encodes meshlet data into an array of bytes that is generally smaller and compresses better compared to original.
	* Returns encoded data size on success, 0 on error; the only error condition is if buffer doesn't have enough space
	* This function encodes a single meshlet; when encoding multiple meshlets, additional headers may be necessary to store vertex/triangle count and encoded size.
	* For maximum efficiency the meshlet being encoded should be optimized using meshopt_optimizeMeshletLevel with level 1+ (3 recommended); additionally, vertex reference data should be optimized for locality (fetch).
	*
	* buffer must contain enough space for the encoded meshlet (use meshopt_encodeMeshletBound to compute worst case size)
	* vertices may be NULL, in which case vertex_count must be 0 and only triangle data is encoded
	* vertex_count and triangle_count must be <= 256.
	*/
	encodeMeshlet      :: proc(buffer: ^c.uchar, buffer_size: c.size_t, vertices: ^c.uint, vertex_count: c.size_t, triangles: ^c.uchar, triangle_count: c.size_t) -> c.size_t ---
	encodeMeshletBound :: proc(max_vertices: c.size_t, max_triangles: c.size_t) -> c.size_t ---

	/**
	* Meshlet decoder
	* Decodes meshlet data from an array of bytes generated by meshopt_encodeMeshlet
	* Returns 0 if decoding was successful, and an error code otherwise
	* The decoder is safe to use for untrusted input, but it may produce garbage data.
	*
	* vertices must contain enough space for the resulting vertex data, aligned to 4 bytes (align(vertex_count * vertex_size, 4) bytes)
	* vertex_size must be 2 (16-bit vertex references) or 4 (32-bit vertex references)
	* triangles must contain enough space for the resulting triangle data, aligned to 4 bytes (align(triangle_count * triangle_size, 4) bytes)
	* triangle_size must be 3 (8-bit triangle indices) or 4 (32-bit packed triangles, stored as (a) | (b << 8) | (c << 16))
	* vertex_count, triangle_count match those used during encoding exactly; buffer_size must be equal to the encoded size returned by meshopt_encodeMeshlet.
	* vertices may be NULL, in which case vertex_count must be 0 and the meshlet must contain just triangle data
	*
	* When using "raw" decoding (meshopt_decodeMeshletRaw), both vertices and triangles should have available space further aligned to 16 bytes for efficient SIMD decoding.
	*/
	decodeMeshlet    :: proc(vertices: rawptr, vertex_count: c.size_t, vertex_size: c.size_t, triangles: rawptr, triangle_count: c.size_t, triangle_size: c.size_t, buffer: ^c.uchar, buffer_size: c.size_t) -> c.int ---
	decodeMeshletRaw :: proc(vertices: ^c.uint, vertex_count: c.size_t, triangles: ^c.uint, triangle_count: c.size_t, buffer: ^c.uchar, buffer_size: c.size_t) -> c.int ---

	/**
	* Vertex buffer encoder
	* Encodes vertex data into an array of bytes that is generally smaller and compresses better compared to original.
	* Returns encoded data size on success, 0 on error; the only error condition is if buffer doesn't have enough space
	* This function works for a single vertex stream; for multiple vertex streams, call meshopt_encodeVertexBuffer for each stream.
	* Note that all vertex_size bytes of each vertex are encoded verbatim, including padding which should be zero-initialized.
	* For maximum efficiency the vertex buffer being encoded has to be quantized and optimized for locality of reference (cache/fetch) first.
	*
	* buffer must contain enough space for the encoded vertex buffer (use meshopt_encodeVertexBufferBound to compute worst case size)
	* vertex_size must be a multiple of 4 (and <= 256)
	*/
	encodeVertexBuffer      :: proc(buffer: ^c.uchar, buffer_size: c.size_t, vertices: rawptr, vertex_count: c.size_t, vertex_size: c.size_t) -> c.size_t ---
	encodeVertexBufferBound :: proc(vertex_count: c.size_t, vertex_size: c.size_t) -> c.size_t ---

	/**
	* Vertex buffer encoder
	* Encodes vertex data just like meshopt_encodeVertexBuffer, but allows to override compression level.
	* For compression level to take effect, the vertex encoding version must be set to 1.
	* The default compression level implied by meshopt_encodeVertexBuffer is 2.
	*
	* buffer must contain enough space for the encoded vertex buffer (use meshopt_encodeVertexBufferBound to compute worst case size)
	* vertex_size must be a multiple of 4 (and <= 256)
	* level should be in the range [0, 3] with 0 being the fastest and 3 being the slowest and producing the best compression ratio.
	* version should be -1 to use the default version (specified via meshopt_encodeVertexVersion), or 0/1 to override the version; per above, level won't take effect if version is 0.
	*/
	encodeVertexBufferLevel :: proc(buffer: ^c.uchar, buffer_size: c.size_t, vertices: rawptr, vertex_count: c.size_t, vertex_size: c.size_t, level: c.int, version: c.int) -> c.size_t ---

	/**
	* Set vertex encoder format version (defaults to 1)
	*
	* This function is not thread safe and must not be called concurrently with meshopt_encodeVertexBuffer/meshopt_encodeVertexBufferLevel.
	*
	* version must specify the data format version to encode; valid values are 0 (decodable by all library versions) and 1 (decodable by 0.23+)
	*/
	encodeVertexVersion :: proc(version: c.int) ---

	/**
	* Vertex buffer decoder
	* Decodes vertex data from an array of bytes generated by meshopt_encodeVertexBuffer
	* Returns 0 if decoding was successful, and an error code otherwise
	* The decoder is safe to use for untrusted input, but it may produce garbage data.
	*
	* destination must contain enough space for the resulting vertex buffer (vertex_count * vertex_size bytes)
	* vertex_size must be a multiple of 4 (and <= 256)
	*/
	decodeVertexBuffer :: proc(destination: rawptr, vertex_count: c.size_t, vertex_size: c.size_t, buffer: ^c.uchar, buffer_size: c.size_t) -> c.int ---

	/**
	* Get encoded vertex format version
	* Returns format version of the encoded vertex buffer, or -1 if the buffer header is invalid
	* Note that a non-negative value doesn't guarantee that the buffer will be decoded correctly if the input is malformed.
	*/
	decodeVertexVersion :: proc(buffer: ^c.uchar, buffer_size: c.size_t) -> c.int ---

	
	/**
	* Vertex buffer filter encoders
	* These functions can be used to encode data in a format that meshopt_decodeFilter can decode
	*
	* meshopt_encodeFilterOct encodes unit vectors with K-bit (2 <= K <= 16) signed X/Y as an output.
	* Each component is stored as an 8-bit or 16-bit normalized integer; stride must be equal to 4 (K <= 8) or 8 (K <= 16). Z will store 1.0f, W is preserved as is.
	* Input data must contain 4 floats for every vector (count*4 total).
	*
	* meshopt_encodeFilterQuat encodes unit quaternions with K-bit (4 <= K <= 16) component encoding.
	* Each component is stored as a 16-bit integer; stride must be equal to 8.
	* Input data must contain 4 floats for every quaternion (count*4 total).
	*
	* meshopt_encodeFilterExp encodes arbitrary (finite) floating-point data with 8-bit exponent and K-bit integer mantissa (1 <= K <= 24).
	* Exponent can be shared between all components of a given vector as defined by stride or all values of a given component; stride must be divisible by 4 (and <= 256).
	* Input data must contain stride/4 floats for every vector (count*stride/4 total).
	*
	* meshopt_encodeFilterColor encodes RGBA color data by converting RGB to YCoCg color space with K-bit (2 <= K <= 16) component encoding; A is stored using K-1 bits.
	* Each component is stored as an 8-bit or 16-bit integer; stride must be equal to 4 (K <= 8) or 8 (K <= 16).
	* Input data must contain 4 floats for every color (count*4 total).
	*/
	decodeFilterOct   :: proc(buffer: rawptr, count: c.size_t, stride: c.size_t) ---
	decodeFilterQuat  :: proc(buffer: rawptr, count: c.size_t, stride: c.size_t) ---
	decodeFilterExp   :: proc(buffer: rawptr, count: c.size_t, stride: c.size_t) ---
	decodeFilterColor :: proc(buffer: rawptr, count: c.size_t, stride: c.size_t) ---

	/**
	* Vertex buffer filter encoders
	* These functions can be used to encode data in a format that meshopt_decodeFilter can decode
	*
	* meshopt_encodeFilterOct encodes unit vectors with K-bit (2 <= K <= 16) signed X/Y as an output.
	* Each component is stored as an 8-bit or 16-bit normalized integer; stride must be equal to 4 or 8. Z will store 1.0f, W is preserved as is.
	* Input data must contain 4 floats for every vector (count*4 total).
	*
	* meshopt_encodeFilterQuat encodes unit quaternions with K-bit (4 <= K <= 16) component encoding.
	* Each component is stored as an 16-bit integer; stride must be equal to 8.
	* Input data must contain 4 floats for every quaternion (count*4 total).
	*
	* meshopt_encodeFilterExp encodes arbitrary (finite) floating-point data with 8-bit exponent and K-bit integer mantissa (1 <= K <= 24).
	* Exponent can be shared between all components of a given vector as defined by stride or all values of a given component; stride must be divisible by 4.
	* Input data must contain stride/4 floats for every vector (count*stride/4 total).
	*
	* meshopt_encodeFilterColor encodes RGBA color data by converting RGB to YCoCg color space with K-bit (2 <= K <= 16) component encoding; A is stored using K-1 bits.
	* Each component is stored as an 8-bit or 16-bit integer; stride must be equal to 4 or 8.
	* Input data must contain 4 floats for every color (count*4 total).
	*/
	encodeFilterOct   :: proc(destination: rawptr, count: c.size_t, stride: c.size_t, bits: c.int, data: ^f32) ---
	encodeFilterQuat  :: proc(destination: rawptr, count: c.size_t, stride: c.size_t, bits: c.int, data: ^f32) ---
	encodeFilterExp   :: proc(destination: rawptr, count: c.size_t, stride: c.size_t, bits: c.int, data: ^f32, mode: Encode_Exp_Mode) ---
	encodeFilterColor :: proc(destination: rawptr, count: c.size_t, stride: c.size_t, bits: c.int, data: ^f32) ---

	/**
	* Mesh simplifier
	* Reduces the number of triangles in the mesh, attempting to preserve mesh appearance as much as possible
	* The algorithm tries to preserve mesh topology and can stop short of the target goal based on topology constraints or target error.
	* If not all attributes from the input mesh are needed, it's recommended to reindex the mesh without them prior to simplification.
	* Returns the number of indices after simplification, with destination containing new index data
	*
	* The resulting index buffer references vertices from the original vertex buffer.
	* If the original vertex data isn't needed, creating a compact vertex buffer using meshopt_optimizeVertexFetch is recommended.
	*
	* destination must contain enough space for the target index buffer, worst case is index_count elements (*not* target_index_count)!
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* target_error represents the error relative to mesh extents that can be tolerated, e.g. 0.01 = 1% deformation (unless absolute error option is used)
	* options must be a bitmask composed of meshopt_SimplifyX options; 0 is a safe default
	* result_error can be NULL; when it's not NULL, it will contain the resulting (relative/absolute) error after simplification
	*/
	simplify :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, target_index_count: c.size_t, target_error: f32, options: Simplify_Options_Flags, result_error: ^f32) -> c.size_t ---

	/**
	* Mesh simplifier with attribute metric
	* Reduces the number of triangles in the mesh, attempting to preserve mesh appearance as much as possible.
	* Similar to meshopt_simplify, but incorporates attribute values into the error metric used to prioritize simplification order.
	* The algorithm tries to preserve mesh topology and can stop short of the target goal based on topology constraints or target error.
	* If not all attributes from the input mesh are needed, it's recommended to reindex the mesh without them prior to simplification.
	* Returns the number of indices after simplification, with destination containing new index data
	*
	* The resulting index buffer references vertices from the original vertex buffer.
	* If the original vertex data isn't needed, creating a compact vertex buffer using meshopt_optimizeVertexFetch is recommended.
	* Note that the number of attributes with non-zero weights affects memory requirements and running time.
	*
	* destination must contain enough space for the target index buffer, worst case is index_count elements (*not* target_index_count)!
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* vertex_attributes should have attribute_count floats for each vertex
	* attribute_weights should have attribute_count floats in total; the weights determine relative priority of attributes between each other and wrt position
	* attribute_count must be <= 32
	* vertex_lock can be NULL; when it's not NULL, it should have a value for each vertex; 1 denotes vertices that can't be moved
	* target_error represents the error relative to mesh extents that can be tolerated, e.g. 0.01 = 1% deformation; value range [0..1]
	* options must be a bitmask composed of meshopt_SimplifyX options; 0 is a safe default
	* result_error can be NULL; when it's not NULL, it will contain the resulting (relative) error after simplification
	*/
	simplifyWithAttributes :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, vertex_attributes: ^f32, vertex_attributes_stride: c.size_t, attribute_weights: ^f32, attribute_count: c.size_t, vertex_lock: ^c.uchar, target_index_count: c.size_t, target_error: f32, options: Simplify_Options_Flags, result_error: ^f32) -> c.size_t ---

	/**
	* Mesh simplifier with position/attribute update
	* Reduces the number of triangles in the mesh, attempting to preserve mesh appearance as much as possible.
	* Similar to meshopt_simplifyWithAttributes, but destructively updates positions and attribute values for optimal appearance.
	* The algorithm tries to preserve mesh topology and can stop short of the target goal based on topology constraints or target error.
	* If not all attributes from the input mesh are needed, it's recommended to reindex the mesh without them prior to simplification.
	* Returns the number of indices after simplification, indices are destructively updated with new index data
	*
	* The updated index buffer references vertices from the original vertex buffer, however the vertex positions and attributes are updated in-place.
	* Creating a compact vertex buffer using meshopt_optimizeVertexFetch is recommended; if the original vertex data is needed, it should be copied before simplification.
	* Note that the number of attributes with non-zero weights affects memory requirements and running time. Attributes with zero weights are not updated.
	*
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* vertex_attributes should have attribute_count floats for each vertex
	* attribute_weights should have attribute_count floats in total; the weights determine relative priority of attributes between each other and wrt position
	* attribute_count must be <= 32
	* vertex_lock can be NULL; when it's not NULL, it should have a value for each vertex; 1 denotes vertices that can't be moved
	* target_error represents the error relative to mesh extents that can be tolerated, e.g. 0.01 = 1% deformation; value range [0..1]
	* options must be a bitmask composed of meshopt_SimplifyX options; 0 is a safe default
	* result_error can be NULL; when it's not NULL, it will contain the resulting (relative) error after simplification
	*/
	simplifyWithUpdate :: proc(indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, vertex_attributes: ^f32, vertex_attributes_stride: c.size_t, attribute_weights: ^f32, attribute_count: c.size_t, vertex_lock: ^c.uchar, target_index_count: c.size_t, target_error: f32, options: Simplify_Options_Flags, result_error: ^f32) -> c.size_t ---

	/**
	* Mesh simplifier (sloppy)
	* Reduces the number of triangles in the mesh, sacrificing mesh appearance for simplification performance
	* The algorithm doesn't preserve mesh topology but can stop short of the target goal based on target error.
	* Returns the number of indices after simplification, with destination containing new index data
	* The resulting index buffer references vertices from the original vertex buffer.
	* If the original vertex data isn't needed, creating a compact vertex buffer using meshopt_optimizeVertexFetch is recommended.
	*
	* destination must contain enough space for the target index buffer, worst case is index_count elements (*not* target_index_count)!
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* vertex_lock can be NULL; when it's not NULL, it should have a value for each vertex; vertices that can't be moved should set 1 consistently for all indices with the same position
	* target_error represents the error relative to mesh extents that can be tolerated, e.g. 0.01 = 1% deformation; value range [0..1]
	* result_error can be NULL; when it's not NULL, it will contain the resulting (relative) error after simplification
	*/
	simplifySloppy :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, vertex_lock: ^c.uchar, target_index_count: c.size_t, target_error: f32, result_error: ^f32) -> c.size_t ---

	/**
	* Mesh simplifier (pruner)
	* Reduces the number of triangles in the mesh by removing small isolated parts of the mesh
	* Returns the number of indices after simplification, with destination containing new index data
	* The resulting index buffer references vertices from the original vertex buffer.
	* If the original vertex data isn't needed, creating a compact vertex buffer using meshopt_optimizeVertexFetch is recommended.
	*
	* destination must contain enough space for the target index buffer, worst case is index_count elements
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* target_error represents the error relative to mesh extents that can be tolerated, e.g. 0.01 = 1% deformation; value range [0..1]
	*/
	simplifyPrune :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, target_error: f32) -> c.size_t ---

	/**
	* Point cloud simplifier
	* Reduces the number of points in the cloud to reach the given target
	* Returns the number of points after simplification, with destination containing new index data
	* The resulting index buffer references vertices from the original vertex buffer.
	* If the original vertex data isn't needed, creating a compact vertex buffer using meshopt_optimizeVertexFetch is recommended.
	*
	* destination must contain enough space for the target index buffer (target_vertex_count elements)
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* vertex_colors can be NULL; when it's not NULL, it should have float3 color in the first 12 bytes of each vertex
	* color_weight determines relative priority of color wrt position; 1.0 is a safe default
	*/
	simplifyPoints :: proc(destination: ^c.uint, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, vertex_colors: ^f32, vertex_colors_stride: c.size_t, color_weight: f32, target_vertex_count: c.size_t) -> c.size_t ---

	/**
	* Returns the error scaling factor used by the simplifier to convert between absolute and relative extents
	*
	* Absolute error must be *divided* by the scaling factor before passing it to meshopt_simplify as target_error
	* Relative error returned by meshopt_simplify via result_error must be *multiplied* by the scaling factor to get absolute error.
	*/
	simplifyScale :: proc(vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) -> f32 ---

	/**
	* Mesh stripifier
	* Converts a previously vertex cache optimized triangle list to triangle strip, stitching strips using restart index or degenerate triangles
	* Returns the number of indices in the resulting strip, with destination containing new index data
	* For maximum efficiency the index buffer being converted has to be optimized for vertex cache first.
	* Using restart indices can result in ~10% smaller index buffers, but on some GPUs restart indices may result in decreased performance.
	*
	* destination must contain enough space for the target index buffer, worst case can be computed with meshopt_stripifyBound
	* restart_index should be 0xffff or 0xffffffff depending on index size, or 0 to use degenerate triangles
	*/
	stripify      :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t, restart_index: c.uint) -> c.size_t ---
	stripifyBound :: proc(index_count: c.size_t) -> c.size_t ---

	/**
	* Mesh unstripifier
	* Converts a triangle strip to a triangle list
	* Returns the number of indices in the resulting list, with destination containing new index data
	*
	* destination must contain enough space for the target index buffer, worst case can be computed with meshopt_unstripifyBound
	*/
	unstripify      :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, restart_index: c.uint) -> c.size_t ---
	unstripifyBound :: proc(index_count: c.size_t) -> c.size_t ---

	/**
	* Vertex transform cache analyzer
	* Returns cache hit statistics using a simplified FIFO model
	* Results may not match actual GPU performance
	*/
	analyzeVertexCache :: proc(indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t, cache_size: c.uint, warp_size: c.uint, primgroup_size: c.uint) -> Vertex_Cache_Statistics ---

	/**
	* Vertex fetch cache analyzer
	* Returns cache hit statistics using a simplified direct mapped model
	* Results may not match actual GPU performance
	*/
	analyzeVertexFetch :: proc(indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t, vertex_size: c.size_t) -> Vertex_Fetch_Statistics ---

	/**
	* Overdraw analyzer
	* Returns overdraw statistics using a software rasterizer
	* Results may not match actual GPU performance
	*
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	*/
	analyzeOverdraw :: proc(indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) -> Overdraw_Statistics ---

	/**
	* Coverage analyzer
	* Returns coverage statistics (ratio of viewport pixels covered from each axis) using a software rasterizer
	*
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	*/
	analyzeCoverage :: proc(indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) -> Coverage_Statistics ---

	/**
	* Meshlet builder
	* Splits the mesh into a set of meshlets where each meshlet has a micro index buffer indexing into meshlet vertices that refer to the original vertex buffer
	* The resulting data can be used to render meshes using NVidia programmable mesh shading pipeline, or in other cluster-based renderers.
	* When targeting mesh shading hardware, for maximum efficiency meshlets should be further optimized using meshopt_optimizeMeshlet.
	* When using buildMeshlets, vertex positions need to be provided to minimize the size of the resulting clusters.
	* When using buildMeshletsScan, for maximum efficiency the index buffer being converted has to be optimized for vertex cache first.
	*
	* meshlets must contain enough space for all meshlets, worst case size can be computed with meshopt_buildMeshletsBound
	* meshlet_vertices must contain enough space for all meshlets, worst case is index_count elements (*not* vertex_count!)
	* meshlet_triangles must contain enough space for all meshlets, worst case is index_count elements
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* max_vertices and max_triangles must not exceed implementation limits (max_vertices <= 256, max_triangles <= 512)
	* cone_weight should be set to 0 when cone culling is not used, and a value between 0 and 1 otherwise to balance between cluster size and cone culling efficiency
	*/
	buildMeshlets      :: proc(meshlets: ^Meshlet, meshlet_vertices: ^c.uint, meshlet_triangles: ^c.uchar, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, max_vertices: c.size_t, max_triangles: c.size_t, cone_weight: f32) -> c.size_t ---
	buildMeshletsScan  :: proc(meshlets: ^Meshlet, meshlet_vertices: ^c.uint, meshlet_triangles: ^c.uchar, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t, max_vertices: c.size_t, max_triangles: c.size_t) -> c.size_t ---
	buildMeshletsBound :: proc(index_count: c.size_t, max_vertices: c.size_t, max_triangles: c.size_t) -> c.size_t ---

	/**
	* Meshlet builder with flexible cluster sizes
	* Splits the mesh into a set of meshlets, similarly to meshopt_buildMeshlets, but allows to specify minimum and maximum number of triangles per meshlet.
	* Clusters between min and max triangle counts are split when the cluster size would have exceeded the expected cluster size by more than split_factor.
	*
	* meshlets must contain enough space for all meshlets, worst case size can be computed with meshopt_buildMeshletsBound using min_triangles (*not* max!)
	* meshlet_vertices must contain enough space for all meshlets, worst case is index_count elements (*not* vertex_count!)
	* meshlet_triangles must contain enough space for all meshlets, worst case is index_count elements
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* max_vertices, min_triangles and max_triangles must not exceed implementation limits (max_vertices <= 256, max_triangles <= 512; min_triangles <= max_triangles)
	* cone_weight should be set to 0 when cone culling is not used, and a value between 0 and 1 otherwise to balance between cluster size and cone culling efficiency
	* split_factor should be set to a non-negative value; when greater than 0, clusters that have large bounds may be split unless they are under the min_triangles threshold
	*/
	buildMeshletsFlex :: proc(meshlets: ^Meshlet, meshlet_vertices: ^c.uint, meshlet_triangles: ^c.uchar, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, max_vertices: c.size_t, min_triangles: c.size_t, max_triangles: c.size_t, cone_weight: f32, split_factor: f32) -> c.size_t ---

	/**
	* Meshlet builder that produces clusters optimized for raytracing
	* Splits the mesh into a set of meshlets, similarly to meshopt_buildMeshlets, but optimizes cluster subdivision for raytracing and allows to specify minimum and maximum number of triangles per meshlet.
	*
	* meshlets must contain enough space for all meshlets, worst case size can be computed with meshopt_buildMeshletsBound using min_triangles (*not* max!)
	* meshlet_vertices must contain enough space for all meshlets, worst case is index_count elements (*not* vertex_count!)
	* meshlet_triangles must contain enough space for all meshlets, worst case is index_count elements
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* max_vertices, min_triangles and max_triangles must not exceed implementation limits (max_vertices <= 256, max_triangles <= 512; min_triangles <= max_triangles)
	* fill_weight allows to prioritize clusters that are closer to maximum size at some cost to SAH quality; 0.5 is a safe default
	*/
	buildMeshletsSpatial :: proc(meshlets: ^Meshlet, meshlet_vertices: ^c.uint, meshlet_triangles: ^c.uchar, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, max_vertices: c.size_t, min_triangles: c.size_t, max_triangles: c.size_t, fill_weight: f32) -> c.size_t ---

	/**
	* Meshlet optimizer
	* Reorders meshlet vertices and triangles to maximize locality which can improve rasterizer throughput or ray tracing performance when using fast-build modes.
	*
	* meshlet_triangles and meshlet_vertices must refer to meshlet data; when buildMeshlets* is used, these need to be computed from meshlet's vertex_offset and triangle_offset
	* triangle_count and vertex_count must not exceed implementation limits (vertex_count <= 256, triangle_count <= 512)
	*/
	optimizeMeshlet :: proc(meshlet_vertices: ^c.uint, meshlet_triangles: ^c.uchar, triangle_count: c.size_t, vertex_count: c.size_t) ---


	/**
	* Meshlet optimizer
	* Reorders meshlet vertices and triangles to maximize locality, with higher levels resulting in smaller compressed size at the cost of optimization time.
	* At level 0 the result is equivalent to meshopt_optimizeMeshlet; levels >= 1 may rotate triangle corners to improve compression (which can change provoking vertex and affect OMM data).
	*
	* level should be in the range [0, 9] with 0 equivalent to meshopt_optimizeMeshlet and 9 being the slowest; the sweet spot for compression ratio is around 3
	*/
	optimizeMeshletLevel :: proc(meshlet_vertices: ^c.uint, vertex_count: c.size_t, meshlet_triangles: ^c.uchar, triangle_count: c.size_t, level: c.int) ---

	/**
	* Cluster bounds generator
	* Creates bounding volumes that can be used for frustum, backface and occlusion culling.
	*
	* For backface culling with orthographic projection, use the following formula to reject backfacing clusters:
	*   dot(view, cone_axis) >= cone_cutoff
	*
	* For perspective projection, you can use the formula that needs cone apex in addition to axis & cutoff:
	*   dot(normalize(cone_apex - camera_position), cone_axis) >= cone_cutoff
	*
	* Alternatively, you can use the formula that doesn't need cone apex and uses bounding sphere instead:
	*   dot(normalize(center - camera_position), cone_axis) >= cone_cutoff + radius / length(center - camera_position)
	* or an equivalent formula that doesn't have a singularity at center = camera_position:
	*   dot(center - camera_position, cone_axis) >= cone_cutoff * length(center - camera_position) + radius
	*
	* The formula that uses the apex is slightly more accurate but needs the apex; if you are already using bounding sphere
	* to do frustum/occlusion culling, the formula that doesn't use the apex may be preferable (for derivation see
	* Real-Time Rendering 4th Edition, section 19.3).
	*
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* vertex_count should specify the number of vertices in the entire mesh, not cluster or meshlet
	* indices should have at most 256 unique vertex indices
	* index_count/3 and triangle_count must not exceed implementation limits (<= 512)
	*/
	computeClusterBounds :: proc(indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) -> Bounds ---
	computeMeshletBounds :: proc(meshlet_vertices: ^c.uint, meshlet_triangles: ^c.uchar, triangle_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) -> Bounds ---

	/**
	* Sphere bounds generator
	* Creates bounding sphere around a set of points or a set of spheres; returns the center and radius of the sphere, with other fields of the result set to 0.
	*
	* positions should have float3 position in the first 12 bytes of each element
	* radii can be NULL; when it's not NULL, it should have a non-negative float radius in the first 4 bytes of each element
	*/
	computeSphereBounds :: proc(positions: ^f32, count: c.size_t, positions_stride: c.size_t, radii: ^f32, radii_stride: c.size_t) -> Bounds ---

	/**
	* Extract meshlet-local vertex and triangle indices from absolute cluster indices.
	* Fills triangles[] and vertices[] such that vertices[triangles[i]] == indices[i], and returns the number of unique vertices.
	*
	* vertices must contain enough space for the resulting references (up to 256 elements)
	* triangles must contain enough space for local indices (index_count elements)
	* indices should have at most 256 unique vertex indices
	* index_count/3 must not exceed implementation limits (<= 512)
	*/
	extractMeshletIndices :: proc(vertices: ^c.uint, triangles: ^c.uchar, indices: ^c.uint, index_count: c.size_t) -> c.size_t ---

	/**
	* Cluster partitioner
	* Partitions clusters into groups of similar size, prioritizing grouping clusters that share vertices or are close to each other.
	* When vertex positions are not provided, only clusters that share vertices will be grouped together, which may result in small partitions for some inputs.
	*
	* destination must contain enough space for the resulting partition data (cluster_count elements)
	* destination[i] will contain the partition id for cluster i, with the total number of partitions returned by the function
	* cluster_indices should have the vertex indices referenced by each cluster, stored sequentially
	* cluster_index_counts should have the number of indices in each cluster; sum of all cluster_index_counts must be equal to total_index_count
	* vertex_positions can be NULL; when it's not NULL, it should have float3 position in the first 12 bytes of each vertex
	* target_partition_size is a target size for each partition, in clusters; the resulting partitions may be smaller or larger (up to target + target/3)
	*/
	partitionClusters :: proc(destination: ^c.uint, cluster_indices: ^c.uint, total_index_count: c.size_t, cluster_index_counts: ^c.uint, cluster_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, target_partition_size: c.size_t) -> c.size_t ---

	/**
	* Spatial sorter
	* Generates a remap table that can be used to reorder points for spatial locality.
	* Resulting remap table maps old vertices to new vertices and can be used in meshopt_remapVertexBuffer.
	*
	* destination must contain enough space for the resulting remap table (vertex_count elements)
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	*/
	spatialSortRemap :: proc(destination: ^c.uint, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) ---

	/**
	* Spatial sorter
	* Reorders triangles for spatial locality, and generates a new index buffer. The resulting index buffer can be used with other functions like optimizeVertexCache.
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	*/
	spatialSortTriangles :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) ---

	/**
	* Spatial clusterizer
	* Reorders points into clusters optimized for spatial locality, and generates a new index buffer.
	* Ensures the output can be split into cluster_size chunks where each chunk has good positional locality. Only the last chunk will be smaller than cluster_size.
	*
	* destination must contain enough space for the resulting index buffer (vertex_count elements)
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	*/
	spatialClusterPoints :: proc(destination: ^c.uint, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, cluster_size: c.size_t) ---

	/**
	* Experimental: Opacity micromap generator (measure)
	* Computes a subdivision level for each input triangle, as well as deduplicating the triangles that reference the same UVs to reduce rasterization requests.
	* Returns the number of OMM entries.
	*
	* levels and sources must contain enough space for the worst case output (index_count/3 elements, one per resulting OMM entry)
	* levels[i] will contain the subdivision level for entry i, with the total number of entries returned by the function; each entry should be rasterized from triangle index sources[i]
	* omm_indices must contain enough space for the resulting OMM indices (index_count/3 elements, one per triangle)
	* vertex_uvs should have float2 texture coordinate in the first 8 bytes of each vertex
	* max_level specifies the maximum subdivision level (0..12)
	* target_edge can be 0; when >0, triangle subdivision is adaptive and targets target_edge^2 texel area
	*/
	opacityMapMeasure :: proc(levels: ^c.uchar, sources: ^c.uint, omm_indices: ^c.int, indices: ^c.uint, index_count: c.size_t, vertex_uvs: ^f32, vertex_count: c.size_t, vertex_uvs_stride: c.size_t, texture_width: c.uint, texture_height: c.uint, max_level: c.int, target_edge: f32) -> c.size_t ---

	/**
	* Experimental: Opacity micromap generator (rasterize)
	* Rasterizes opacity state for a single triangle entry by sampling the alpha texture, using bilinear filtering and 0.5 alpha cutoff.
	*
	* result should contain enough space for the output opacity data (which can be computed using meshopt_opacityMapEntrySize)
	* level specifies the subdivision level (0..12)
	* states should be 2 for 2-state format (opaque/transparent) and 4 for 4-state format (opaque/transparent/unknown)
	* uv0/uv1/uv2 should refer to a float2 texture coordinate for each triangle corner; note that micromap data is sensitive to the corner order
	* texture_data should point to the alpha channel of the first pixel, encoded as UNORM8
	* texture_stride specifies the distance in bytes between consecutive pixels, e.g. 4 for RGBA input
	* texture_pitch specifies the distance in bytes between consecutive rows, e.g. 4*texture_width for tightly packed RGBA input
	*/
	opacityMapRasterize :: proc(result: ^c.uchar, level: c.int, states: c.int, uv0: ^f32, uv1: ^f32, uv2: ^f32, texture_data: ^c.uchar, texture_stride: c.size_t, texture_pitch: c.size_t, texture_width: c.uint, texture_height: c.uint) ---
	opacityMapEntrySize :: proc(level: c.int, states: c.int) -> c.size_t ---

	/**
	* Experimental: Opacity micromap generator (compact)
	* Compacts and deduplicates opacity data, merging identical micromap entries and replacing micromap states with special indices (-4..-1) when possible.
	* Returns the number of OMM entries after compaction; the data array should be trimmed using the last offset/size.
	*
	* data should contain opacity data for all input/output entries
	* levels should contain subdivision levels for all input/output entries
	* offsets should contain offset into data[] for each entry
	* levels[i] and offsets[i] will be updated with post-compaction level/offset for entry i, with the total number of entries returned by the function
	* omm_indices should contain indices into the original OMM data, and will be updated with a new index or a special index (-4..-1) when possible
	* states should be 2 for 2-state format (opaque/transparent) and 4 for 4-state format (opaque/transparent/unknown)
	*/
	opacityMapCompact :: proc(data: ^c.uchar, data_size: c.size_t, levels: ^c.uchar, offsets: ^c.uint, omm_count: c.size_t, omm_indices: ^c.int, triangle_count: c.size_t, states: c.int) -> c.size_t ---

	/**
	* Experimental: Tangent space generator
	* Computes per-corner tangent vectors; for each corner, computes normalized tangent vector (xyz) and orientation (w, +/-1).
	* Bitangent can be reconstructed via cross(normal, tangent.xyz) * tangent.w.
	* To apply tangents to the mesh, either deindex and reindex it with the tangent stream, or copy tangents to existing vertex data while duplicating
	* vertices with different tangent vectors (e.g. on UV mirror seams).
	* Input can be indexed or unindexed (indices=NULL); this does not affect the resulting tangents, but indexed inputs are ~30% faster to process.
	*
	* result must contain enough space for the output tangent data (index_count*4 elements)
	* indices can be NULL if the input is unindexed
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* vertex_normals should have unit float3 normal in the first 12 bytes of each vertex
	* vertex_uvs should have float2 texture coordinate in the first 8 bytes of each vertex
	*/
	generateTangents :: proc(result: ^f32, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, vertex_normals: ^f32, vertex_normals_stride: c.size_t, vertex_uvs: ^f32, vertex_uvs_stride: c.size_t, options: Tangent_Options_Flags) ---

	/**
	* Quantize a float into half-precision (as defined by IEEE-754 fp16) floating point value
	* Generates +-inf for overflow, preserves NaN, flushes denormals to zero, rounds to nearest
	* Representable magnitude range: [6e-5; 65504]
	* Maximum relative reconstruction error: 5e-4
	*/
	quantizeHalf :: proc(v: f32) -> c.ushort ---

	/**
	* Quantize a float into a floating point value with a limited number of significant mantissa bits, preserving the IEEE-754 fp32 binary representation
	* Preserves infinities/NaN, flushes denormals to zero, rounds to nearest
	* Assumes N is in a valid mantissa precision range, which is 1..23
	*/
	quantizeFloat :: proc(v: f32, N: c.int) -> f32 ---

	/**
	* Reverse quantization of a half-precision (as defined by IEEE-754 fp16) floating point value
	* Preserves Inf/NaN, flushes denormals to zero
	*/
	dequantizeHalf :: proc(h: c.ushort) -> f32 ---

	/**
	* Experimental: Compute shared exponent suitable for mesh/cluster position quantization
	* Given mesh or cluster bounds, compute a shared exponent that can be used to quantize any position inside the bounds to a 24-bit integer grid.
	* The resulting output can be stored as a compact bit-stream to be decoded directly in shaders, or to be used as an input to RT BVH builders,
	* for example via D3D12_VERTEX_FORMAT_COMPRESSED1 in DXR2 (max_bits=16).
	*
	* To quantize positions, compute:
	*   scale = pow(2, exponent)
	*   iv = int(round(v / scale))
	* The resulting integer can be stored as signed 24-bit, or as an unsigned offset from a signed 24-bit anchor value, shared between all positions.
	*
	* minv/maxv specify the axis-aligned bounding box of the mesh or cluster; each should refer to a float3 value
	* min_exp specifies the minimum value for the returned exponent, limiting precision to reduce size; e.g. min_exp = -10 will produce minimum error of 1mm given metric units
	* max_bits specifies the maximum allowed number of bits for the quantized integer range (offset from anchor is an unsigned integer up to 2^max_bits-1)
	*/
	computePositionExponent :: proc(minv: ^f32, maxv: ^f32, min_exp: c.int, max_bits: c.int) -> c.int ---

	/**
	* Set allocation callbacks
	* These callbacks will be used instead of the default operator new/operator delete for all temporary allocations in the library.
	* Note that all algorithms only allocate memory for temporary use.
	* allocate/deallocate are always called in a stack-like order - last pointer to be allocated is deallocated first.
	* This function is not thread safe and must not be called concurrently with any other meshopt_ function.
	*
	* In shared library builds, allocations from templated index wrappers in this header will only be redirected if MESHOPTIMIZER_ALLOC_EXPORT is defined.
	*/
	setAllocator :: proc(allocate: proc "c" (c.size_t) -> rawptr, deallocate: proc "c" (rawptr)) ---
}
