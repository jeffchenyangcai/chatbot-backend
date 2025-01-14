from retrievers.my_retriever import MyRetriever
from text2vec import SentenceModel
import weaviate
from fastapi import FastAPI, Form, HTTPException
from typing import List
from pydantic import BaseModel
from langchain.text_splitter import CharacterTextSplitter,RecursiveCharacterTextSplitter
from langchain_community.document_loaders import TextLoader
import os
# 定义文本拆分方法
def get_vector_text_splitter(
    separator=["\n\n\n", "\n\n", "\n", " "],
    chunk_size=512,
    chunk_overlap=5,
    length_function=len,
    is_separator_regex=False
):
    return RecursiveCharacterTextSplitter(
        separators=separator,
        chunk_size=chunk_size,
        chunk_overlap=chunk_overlap,
        length_function=length_function,
        is_separator_regex=is_separator_regex,
    )

app = FastAPI()

client = weaviate.Client(url='http://localhost:8080')
model = SentenceModel('D:/download/m3e_base')

# 定义请求体的数据模型
class QueryRequest(BaseModel):
    user_id: int
    knowledge_base_id: int
    question: str

# 动态生成类名
def generate_class_name(user_id: int, knowledge_base_id: int) -> str:
    return f"Text_{user_id}_{knowledge_base_id}_class"

print("success generate")
@app.get("/")
async def root():
    return {"message": "Hello World"}

@app.post("/retrieve")
def retrieve(question: str, class_name: str, k: int = 30):
    retriever = MyRetriever(client=client, model=model, class_name=class_name, k=k)
    documents = retriever._get_relevant_documents(question)
    return {"documents": [doc.page_content for doc in documents]}


@app.post("/generate")
def generate(question: str, context: str):
    # 模拟生成回答（可以替换为实际大模型调用）
    return {"answer": f"基于上下文生成的回答: {context[:100]}..."}

class ProcessFilesRequest(BaseModel):
    class_name: str
    file_paths: List[str]

@app.post("/process_files")
#
async def process_files(request: ProcessFilesRequest):
    print("begin process_files")
    try:
        class_name = request.class_name
        file_paths = request.file_paths
        print("start")
        # 如果 Weaviate 中已存在该 class，先删除
        existing_classes = client.schema.get()["classes"]
        if any(c["class"] == class_name for c in existing_classes):
            client.schema.delete_class(class_name)

        # 创建新的 Weaviate class
        class_obj = {
            "class": class_name,

            "vectorIndexConfig": {"distance": "l2-squared"},
        }
        client.schema.create_class(class_obj)

        splitter = get_vector_text_splitter()
        splitted_docs = []
        for file_path in file_paths:
            if not os.path.exists(file_path):
                raise HTTPException(status_code=400, detail=f"File not found: {file_path}")

            # 使用 TextLoader 读文件（可自动处理编码）
            print(1)
            loader = TextLoader(file_path, encoding="utf-8")
            docs = loader.load()
            print(2)
#             if len(docs[0].page_content) < 20:
#                 continue
#
#             chunks = splitter.split_documents(docs)
#             valid_chunks = [ck for ck in chunks if len(ck.page_content) >= 20]
#             splitted_docs.extend(valid_chunks)
            chunks = splitter.split_documents(docs)
            splitted_docs.extend(chunks)

        # 去重
        unique_docs_dict = {doc.page_content: doc for doc in splitted_docs}
        unique_docs = list(unique_docs_dict.values())
        print(unique_docs)
        page_content_list = [doc.page_content for doc in unique_docs]

        # 计算 embeddings
        sentence_embeddings = model.encode(page_content_list)

        # 批量写入 Weaviate
        with client.batch(batch_size=100) as batch:
            for i, (sentence, embedding) in enumerate(zip(page_content_list, sentence_embeddings)):
                properties = {"sentence_id": i, "sentence": sentence}
                client.batch.add_data_object(
                    properties,
                    class_name=class_name,
                    vector=embedding.tolist()
                )

        return {"success": True, "message": "Files processed successfully"}

    except Exception as e:
        # 用 traceback 获取完整的错误堆栈信息
        import traceback
        print(3)
        traceback_str = traceback.format_exc()
        print(traceback_str)
        return {
            "success": False,
            "error": str(e),
            "traceback": traceback_str
        }

@app.post("/search")
async def search_knowledge(request: QueryRequest):
    try:
        # 动态生成类名
        class_name = generate_class_name(request.user_id, request.knowledge_base_id)

        # 将问题生成向量
        query_vector = model.encode([request.question])[0].tolist()

        # 构造检索条件
        near_vector = {"vector": query_vector}

        # 使用 Weaviate 客户端检索
        response = (
            client.query
            .get(class_name, ["sentence_id", "sentence"])  # 检索类名和需要返回的字段
            .with_near_vector(near_vector)                # 向量检索条件
            .with_limit(10)                               # 返回前 10 条结果
            .with_additional(["distance"])               # 输出距离信息
            .do()
        )

        # 解析结果
        results = response.get("data", {}).get("Get", {}).get(class_name, [])
        if not results:
            return {"message": "No relevant knowledge found."}

        # 构造返回结果
        output = []
        for item in results:
            output.append({
                "distance": item["_additional"]["distance"],
                "sentence_id": item["sentence_id"],
                "sentence": item["sentence"],
            })

        # 只将所有 sentence 拼接为一个字符串
        sentences_str = "\n".join(item["sentence"] for item in results)

        # 直接返回拼接后的字符串
        return {"results": sentences_str}

    except Exception as e:
        # 捕获异常并返回错误信息
        raise HTTPException(status_code=500, detail=f"An error occurred: {str(e)}")