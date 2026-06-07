package main

import (
	"context"
	"io"
	"net/http"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"gopkg.in/yaml.v3"
)

const scheduleKey = "schedule.yaml"

type s3Client interface {
	GetObject(ctx context.Context, params *s3.GetObjectInput, optFns ...func(*s3.Options)) (*s3.GetObjectOutput, error)
	PutObject(ctx context.Context, params *s3.PutObjectInput, optFns ...func(*s3.Options)) (*s3.PutObjectOutput, error)
}

type handler struct {
	s3                 s3Client
	bucket             string
	originVerifySecret string
}

func (h *handler) handle(ctx context.Context, req events.LambdaFunctionURLRequest) (events.LambdaFunctionURLResponse, error) {
	if h.originVerifySecret != "" && req.Headers["x-origin-verify"] != h.originVerifySecret {
		return events.LambdaFunctionURLResponse{StatusCode: http.StatusForbidden}, nil
	}
	switch req.RequestContext.HTTP.Method {
	case http.MethodGet:
		return h.getSchedule(ctx)
	case http.MethodPut:
		return h.putSchedule(ctx, req.Body)
	default:
		return events.LambdaFunctionURLResponse{StatusCode: http.StatusMethodNotAllowed}, nil
	}
}

func (h *handler) getSchedule(ctx context.Context) (events.LambdaFunctionURLResponse, error) {
	out, err := h.s3.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(h.bucket),
		Key:    aws.String(scheduleKey),
	})
	if err != nil {
		return errResponse(http.StatusInternalServerError, "failed to read schedule"), nil
	}
	defer out.Body.Close()

	body, err := io.ReadAll(out.Body)
	if err != nil {
		return errResponse(http.StatusInternalServerError, "failed to read schedule body"), nil
	}

	return events.LambdaFunctionURLResponse{
		StatusCode: http.StatusOK,
		Headers:    map[string]string{"Content-Type": "text/yaml; charset=utf-8"},
		Body:       string(body),
	}, nil
}

func (h *handler) putSchedule(ctx context.Context, body string) (events.LambdaFunctionURLResponse, error) {
	// Validate YAML before writing
	var parsed any
	if err := yaml.Unmarshal([]byte(body), &parsed); err != nil {
		return errResponse(http.StatusBadRequest, "invalid YAML: "+err.Error()), nil
	}

	_, err := h.s3.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(h.bucket),
		Key:         aws.String(scheduleKey),
		Body:        strings.NewReader(body),
		ContentType: aws.String("text/yaml; charset=utf-8"),
	})
	if err != nil {
		return errResponse(http.StatusInternalServerError, "failed to save schedule"), nil
	}

	return events.LambdaFunctionURLResponse{StatusCode: http.StatusNoContent}, nil
}

func errResponse(code int, msg string) events.LambdaFunctionURLResponse {
	return events.LambdaFunctionURLResponse{
		StatusCode: code,
		Headers:    map[string]string{"Content-Type": "text/plain"},
		Body:       msg,
	}
}

func main() {
	bucket := os.Getenv("S3_BUCKET")

	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		panic(err)
	}

	h := &handler{
		s3:                 s3.NewFromConfig(cfg),
		bucket:             bucket,
		originVerifySecret: os.Getenv("ORIGIN_VERIFY_SECRET"),
	}

	lambda.Start(h.handle)
}
