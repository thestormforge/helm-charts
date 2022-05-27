package charts

import "embed"

//go:embed all:optimize-controller/**
// OptimizeController is the Helm chart source for Optimize Pro.
var OptimizeController embed.FS

//go:embed all:optimize-live/**
// OptimizeLive is the Helm chart source for Optimize Live.
var OptimizeLive embed.FS
