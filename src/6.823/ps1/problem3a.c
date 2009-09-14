void task(uint64_t* a, uint64_t* b, uint64_t* sums,
		  uint64_t* differences) {
	for (uint64_t i = 0; i < 10; i++) {
		sums[i] = a[i] + b[i];
		differences[i] = a[i] + b[i];
	}
}
