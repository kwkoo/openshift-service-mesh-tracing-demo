package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/opentracing/opentracing-go"
	"github.com/opentracing/opentracing-go/ext"
	"github.com/uber/jaeger-client-go"
	"github.com/uber/jaeger-client-go/zipkin"
)

// Code taken from:
// https://gist.github.com/stevenc81/2c6840784c6223cdbd62cdd1563a4811
//

type logAdapter struct{}

func (l logAdapter) Error(msg string) {
	log.Print(msg)
}
func (l logAdapter) Infof(msg string, args ...interface{}) {
	log.Printf(msg, args...)
}

func handler(w http.ResponseWriter, r *http.Request) {
	message := "Hello!"

	w.Header().Set("Content-Type", "text/plain")

	// do not log requests from probes
	//
	if strings.HasPrefix(r.Header.Get("User-Agent"), "kube-probe") {
		fmt.Fprint(w, "OK")
		return
	}

	tracer := opentracing.GlobalTracer()

	spanCtx, err := tracer.Extract(opentracing.HTTPHeaders, opentracing.HTTPHeadersCarrier(r.Header))
	if err != nil {
		log.Print("error extracting tag from request:", err)
	}
	span := tracer.StartSpan("handler", ext.RPCServerOption(spanCtx))
	defer span.Finish()

	log.Print("Request for URI: ", r.URL.Path)
	log.Print("Method: ", r.Method)
	for key, value := range r.Header {
		log.Print("Header: ", key, " = ", value)
	}

	if len(os.Getenv("MESSAGE")) > 0 {
		message = os.Getenv("MESSAGE")
	}

	fmt.Fprintf(w, "%s: %s\n", os.Getenv("HOSTNAME"), message)

	span.SetTag("path", r.URL.Path)
	span.SetTag("message", message)
}

func main() {
	var port int

	flag.IntVar(&port, "port", 8080, "HTTP listener port")
	flag.Parse()

	env := getPortEnv()
	if env > 0 {
		port = env
	}

	// Initialize tracer with a zipkin extractor
	sampler := jaeger.NewConstSampler(true)
	sender, err := jaeger.NewUDPTransport("jaeger-agent.istio-system:5775", 0)
	if err != nil {
		log.Fatal("could not instantiate jaeger sender:", err)
	}
	reporter := jaeger.NewCompositeReporter(
		jaeger.NewLoggingReporter(logAdapter{}),
		jaeger.NewRemoteReporter(sender, jaeger.ReporterOptions.BufferFlushInterval(1*time.Second)))
	zipkinPropagator := zipkin.NewZipkinB3HTTPHeaderPropagator()
	extractor := jaeger.TracerOptions.Extractor(opentracing.HTTPHeaders, zipkinPropagator)
	zipkinSharedRPCSpan := jaeger.TracerOptions.ZipkinSharedRPCSpan(true)
	tracer, closer := jaeger.NewTracer("simpleweb", sampler, reporter, extractor, zipkinSharedRPCSpan)
	// Set the singleton opentracing.Tracer with the Jaeger tracer.
	opentracing.SetGlobalTracer(tracer)
	defer closer.Close()

	// Setup signal handling.
	shutdown := make(chan os.Signal)
	signal.Notify(shutdown, os.Interrupt)

	var wg sync.WaitGroup
	server := &http.Server{
		Addr:    fmt.Sprintf(":%d", port),
		Handler: http.HandlerFunc(handler),
	}
	go func() {
		log.Printf("listening on port %v", port)
		http.HandleFunc("/", handler)
		wg.Add(1)
		defer wg.Done()
		if err := server.ListenAndServe(); err != nil {
			if err == http.ErrServerClosed {
				log.Print("web server graceful shutdown")
				return
			}
			log.Fatal(err)
		}
	}()

	// Wait for SIGINT
	<-shutdown
	log.Print("interrupt signal received, initiating web server shutdown...")
	signal.Reset(os.Interrupt)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	server.Shutdown(ctx)

	wg.Wait()
	log.Print("Shutdown successful")
}

func getPortEnv() int {
	s := os.Getenv("PORT")
	if len(s) == 0 {
		return 0
	}
	i, err := strconv.Atoi(s)
	if err != nil {
		return 0
	}
	return i
}
