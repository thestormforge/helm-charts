package charts

import "embed"

//go:embed optimize-controller/**
// OptimizeController is the Helm chart source for Optimize Pro.
var OptimizeController embed.FS

//go:embed optimize-live/**
// OptimizeLive is the Helm chart source for Optimize Live.
var OptimizeLive embed.FS
