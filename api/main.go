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

type s3Client interface {
	GetObject(ctx context.Context, params *s3.GetObjectInput, optFns ...func(*s3.Options)) (*s3.GetObjectOutput, error)
	PutObject(ctx context.Context, params *s3.PutObjectInput, optFns ...func(*s3.Options)) (*s3.PutObjectOutput, error)
}

type handler struct {
	s3          s3Client
	bucket      string
	scheduleKey string
}

func (h *handler) handle(ctx context.Context, req events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	switch req.RequestContext.HTTP.Method {
	case http.MethodGet:
		return h.getSchedule(ctx)
	case http.MethodPut:
		return h.putSchedule(ctx, req.Body)
	default:
		return events.APIGatewayV2HTTPResponse{StatusCode: http.StatusMethodNotAllowed}, nil
	}
}

func (h *handler) getSchedule(ctx context.Context) (events.APIGatewayV2HTTPResponse, error) {
	out, err := h.s3.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(h.bucket),
		Key:    aws.String(h.scheduleKey),
	})
	if err != nil {
		return errResponse(http.StatusInternalServerError, "failed to read schedule"), nil
	}
	defer out.Body.Close()

	body, err := io.ReadAll(out.Body)
	if err != nil {
		return errResponse(http.StatusInternalServerError, "failed to read schedule body"), nil
	}

	return events.APIGatewayV2HTTPResponse{
		StatusCode: http.StatusOK,
		Headers:    map[string]string{"Content-Type": "text/yaml; charset=utf-8"},
		Body:       string(body),
	}, nil
}

func (h *handler) putSchedule(ctx context.Context, body string) (events.APIGatewayV2HTTPResponse, error) {
	var parsed any
	if err := yaml.Unmarshal([]byte(body), &parsed); err != nil {
		return errResponse(http.StatusBadRequest, "invalid YAML: "+err.Error()), nil
	}

	_, err := h.s3.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(h.bucket),
		Key:         aws.String(h.scheduleKey),
		Body:        strings.NewReader(body),
		ContentType: aws.String("text/yaml; charset=utf-8"),
	})
	if err != nil {
		return errResponse(http.StatusInternalServerError, "failed to save schedule"), nil
	}

	return events.APIGatewayV2HTTPResponse{StatusCode: http.StatusNoContent}, nil
}

func errResponse(code int, msg string) events.APIGatewayV2HTTPResponse {
	return events.APIGatewayV2HTTPResponse{
		StatusCode: code,
		Headers:    map[string]string{"Content-Type": "text/plain"},
		Body:       msg,
	}
}

func main() {
	key := os.Getenv("S3_KEY")
	if key == "" {
		key = "schedule.yaml"
	}

	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		panic(err)
	}

	h := &handler{
		s3:          s3.NewFromConfig(cfg),
		bucket:      os.Getenv("S3_BUCKET"),
		scheduleKey: key,
	}

	lambda.Start(h.handle)
}
