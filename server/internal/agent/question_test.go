package agent

import (
	"encoding/json"
	"testing"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func TestAnswersGoIntoTheQuestionInput(t *testing.T) {
	input := json.RawMessage(`{"questions":[{"question":"Which DB?","header":"DB","options":[{"label":"Postgres"},{"label":"SQLite"}],"multiSelect":false}]}`)
	var got struct {
		Questions []struct {
			Question string `json:"question"`
		} `json:"questions"`
		Answers map[string]string `json:"answers"`
	}
	if err := json.Unmarshal(withAnswers(input, map[string]string{"Which DB?": "Postgres"}), &got); err != nil {
		t.Fatal(err)
	}
	if len(got.Questions) != 1 || got.Questions[0].Question != "Which DB?" || got.Answers["Which DB?"] != "Postgres" {
		t.Fatalf("questions must stay and answers be added, got %+v", got)
	}
	if string(withAnswers(input, nil)) != string(input) {
		t.Fatal("no answers should leave the input as it was")
	}
	if approvalKind("AskUserQuestion") != v1.ApprovalRequest_KIND_QUESTION || approvalKind("Bash") != v1.ApprovalRequest_KIND_TOOL {
		t.Fatal("only AskUserQuestion is a question")
	}
}
