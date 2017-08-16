//
//  OpenGLView.swift
//  HelloOpenGL
//
//  Created by 川崎隆介 on 2017/08/16.
//  Copyright © 2017年 codable. All rights reserved.
//

import Foundation
import UIKit
import QuartzCore
import OpenGLES
import GLKit

struct Vertex {
    var Position: (Float, Float, Float)
    var Color: (Float, Float, Float, Float)
}

class OpenGLView: UIView {
    var _context: EAGLContext?
    var _colorRenderBuffer = GLuint()
    var _colorSlot = GLuint()
    var _currentRotation = Float()
    var _depthRenderBuffer = GLuint()
    var _eaglLayer: CAEAGLLayer?
    var _modelViewUniform = GLuint()
    var _positionSlot = GLuint()
    var _projectionUniform = GLuint()

    var _vertices = [
        Vertex(Position: ( 1, -1,  0), Color: (1, 0, 0, 1)),
        Vertex(Position: ( 1,  1,  0), Color: (1, 0, 0, 1)),
        Vertex(Position: (-1,  1,  0), Color: (0, 1, 0, 1)),
        Vertex(Position: (-1, -1,  0), Color: (0, 1, 0, 1))/*,
        
        Vertex(Position: ( 1, -1, -1), Color: (1, 0, 0, 1)),
        Vertex(Position: ( 1,  1, -1), Color: (1, 0, 0, 1)),
        Vertex(Position: (-1,  1, -1), Color: (0, 1, 0, 1)),
        Vertex(Position: (-1, -1, -1), Color: (0, 1, 0, 1))*/
    ]
    
    var _indices : [GLubyte] = [
        // Front
        0, 1, 2,
        2, 3, 0/*,
        // Back
        4, 6, 5,
        4, 7, 6,
        // Left
        2, 7, 3,
        7, 6, 2,
        // Right
        0, 4, 1,
        4, 1, 5,
        // Top
        6, 2, 1,
        1, 6, 5,
        // Bottom
        0, 3, 7,
        0, 7, 4*/
    ]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        if (self.setupLayer() != 0) {
            NSLog("OpenGLView init():  setupLayer() failed")
            return
        }
        if (self.setupContext() != 0) {
            NSLog("OpenGLView init():  setupContext() failed")
            return
        }
        /*
        if (self.setupDepthBuffer() != 0) {
            NSLog("OpenGLView init():  setupDepthBuffer() failed")
            return
        }
        */
        
        if (self.setupRenderBuffer() != 0) {
            NSLog("OpenGLView init():  setupRenderBuffer() failed")
            return
        }
        
        if (self.setupFrameBuffer() != 0) {
            NSLog("OpenGLView init():  setupFrameBuffer() failed")
            return
        }
        
        if (self.compileShaders() != 0) {
            NSLog("OpenGLView init():  compileShaders() failed")
            return
        }
        
        if (self.setupVBOs() != 0) {
            NSLog("OpenGLView init():  setupVBOs() failed")
            return
        }
        /*
        if (self.setupDisplayLink() != 0) {
            NSLog("OpenGLView init():  setupDisplayLink() failed")
        }
        */
        self.render()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override class var layerClass: AnyClass {
        get {
            return CAEAGLLayer.self
        }
    }
    
    func compileShader(shaderName: String, shaderType: GLenum, shader: UnsafeMutablePointer<GLuint>) -> Int {
        let shaderPath = Bundle.main.path(forResource: shaderName, ofType:"glsl")
        var error : NSError?
        let shaderString: NSString?
        do {
            shaderString = try NSString(contentsOfFile: shaderPath!, encoding:String.Encoding.utf8.rawValue)
        } catch let error1 as NSError {
            error = error1
            shaderString = nil
        }
        if error != nil {
            NSLog("OpenGLView compileShader():  error loading shader: %@", error!.localizedDescription)
            return -1
        }
        //シェーダオブジェクトの生成
        shader.pointee = glCreateShader(shaderType)
        if (shader.pointee == 0) {
            NSLog("OpenGLView compileShader():  glCreateShader failed")
            return -1
        }
        var shaderStringUTF8 = shaderString!.utf8String
        var shaderStringLength: GLint = GLint(Int32(shaderString!.length))
        //シェーダオブジェクトにソースコードの引き渡し
        glShaderSource(shader.pointee, 1, &shaderStringUTF8, &shaderStringLength)
        //シェーダのコンパイル
        glCompileShader(shader.pointee);
        var success = GLint()
        
        //シェーダのコンパイルが成功したかどうかをチェック
        glGetShaderiv(shader.pointee, GLenum(GL_COMPILE_STATUS), &success)
        if (success == GL_FALSE) {
            let infoLog = UnsafeMutablePointer<GLchar>.allocate(capacity: 256)
            var infoLogLength = GLsizei()
            
            glGetShaderInfoLog(shader.pointee, GLsizei(MemoryLayout<GLchar>.size * 256), &infoLogLength, infoLog)
            NSLog("OpenGLView compileShader():  glCompileShader() failed:  %@", String(cString: infoLog))
            
            infoLog.deallocate(capacity: 256)
            return -1
        }
        
        return 0
    }
    
    func compileShaders() -> Int {
        let vertexShader = UnsafeMutablePointer<GLuint>.allocate(capacity: 1)
        if (self.compileShader(shaderName: "SimpleVertex", shaderType: GLenum(GL_VERTEX_SHADER), shader: vertexShader) != 0 ) {
            NSLog("OpenGLView compileShaders():  compileShader() failed")
            return -1
        }
        
        let fragmentShader = UnsafeMutablePointer<GLuint>.allocate(capacity: 1)
        if (self.compileShader(shaderName: "SimpleFragment", shaderType: GLenum(GL_FRAGMENT_SHADER), shader: fragmentShader) != 0) {
            NSLog("OpenGLView compileShaders():  compileShader() failed")
            return -1
        }
        
        //プログラムオブジェクトの作成
        let program = glCreateProgram()
        //プログラムオブジェクトに頂点シェーダーを指定
        glAttachShader(program, vertexShader.pointee)
        //プログラムオブジェクトにフラグメントシェーダーを指定
        glAttachShader(program, fragmentShader.pointee)
        //リンク
        glLinkProgram(program)
        
        var success = GLint()
        //リンクに成功可否をチェック
        glGetProgramiv(program, GLenum(GL_LINK_STATUS), &success)
        if (success == GL_FALSE) {
            let infoLog = UnsafeMutablePointer<GLchar>.allocate(capacity: 1024)
            var infoLogLength = GLsizei()
            
            glGetProgramInfoLog(program, GLsizei(MemoryLayout<GLchar>.size * 1024), &infoLogLength, infoLog)
            NSLog("OpenGLView compileShaders():  glLinkProgram() failed:  %@", String(cString:  infoLog))
            
            infoLog.deallocate(capacity: 1024)
            fragmentShader.deallocate(capacity: 1)
            vertexShader.deallocate(capacity: 1)
            
            return -1
        }
        //シェーダーを描画に使用することを宣言
        glUseProgram(program)
        //頂点シェーダのattribute変数を有効化
        _positionSlot = GLuint(glGetAttribLocation(program, "Position"))
        _colorSlot = GLuint(glGetAttribLocation(program, "SourceColor"))
        glEnableVertexAttribArray(_positionSlot)
        glEnableVertexAttribArray(_colorSlot)
        
        /*
        _projectionUniform = GLuint(glGetUniformLocation(program, "Projection"))
        _modelViewUniform = GLuint(glGetUniformLocation(program, "Modelview"))
        
        fragmentShader.deallocate(capacity: 1)
        vertexShader.deallocate(capacity: 1)
         */
        return 0
    }

    func setupLayer() -> Int {
        _eaglLayer = self.layer as? CAEAGLLayer
        if (_eaglLayer == nil) {
            NSLog("setupLayer:  _eaglLayer is nil")
            return -1
        }
        _eaglLayer!.isOpaque = true
        return 0
    }
    
    func setupContext() -> Int {
        //コンテキストの設定
        let api : EAGLRenderingAPI = EAGLRenderingAPI.openGLES2
        _context = EAGLContext(api: api)
        
        if (_context == nil) {
            NSLog("Failed to initialize OpenGLES 2.0 context")
            return -1
        }
        if (!EAGLContext.setCurrent(_context)) {
            NSLog("Failed to set current OpenGL context")
            return -1
        }
        return 0
    }
    
    func setupRenderBuffer() -> Int {
        //レンダーバッファ（描画用メモリ）の生成
        glGenRenderbuffers(1, &_colorRenderBuffer)
        //レンダーバッファをバインド
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), _colorRenderBuffer)
        
        if (_context == nil) {
            NSLog("setupRenderBuffer():  _context is nil")
            return -1
        }
        if (_eaglLayer == nil) {
            NSLog("setupRenderBuffer():  _eagLayer is nil")
            return -1
        }
        //レンダリング用のメモリを確保
        if (_context!.renderbufferStorage(Int(GL_RENDERBUFFER), from: _eaglLayer!) == false) {
            NSLog("setupRenderBuffer():  renderbufferStorage() failed")
            return -1
        }
        return 0
    }
    
    func setupFrameBuffer() -> Int {
        var framebuffer: GLuint = 0
        //フレームバッファの生成
        glGenFramebuffers(1, &framebuffer)
        //フレームバッファのバインド
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer)
        //レンダーバッファをGL_COLOR_ATTACHMENT0スロットにアタッチ
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0),
                                  GLenum(GL_RENDERBUFFER), _colorRenderBuffer)
        return 0
    }
    
    func render() {
        //塗りつぶす色を指定
        glClearColor(0, 104.0/255.0, 55.0/255.0, 1.0)
        //カラーバッファをglClearColorで指定した色で塗りつぶす
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        //ビューポートの設定
        glViewport(0, 0, GLsizei(self.frame.size.width), GLsizei(self.frame.size.height));

        
        let positionSlotFirstComponent = UnsafePointer<Int>(bitPattern:0)
        //glEnableVertexAttribArray(_positionSlot)
        //頂点データの意味づけ(位置）
        glVertexAttribPointer(_positionSlot, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<Vertex>.size), positionSlotFirstComponent)
        
        //glEnableVertexAttribArray(_colorSlot)
        //頂点データの意味づけ（色）
        let colorSlotFirstComponent = UnsafePointer<Int>(bitPattern:MemoryLayout<Float>.size * 3)
        glVertexAttribPointer(_colorSlot, 4, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<Vertex>.size), colorSlotFirstComponent)
        
        let vertexBufferOffset = UnsafeMutableRawPointer(bitPattern: 0)
        glDrawElements(GLenum(GL_TRIANGLES), GLsizei((_indices.count * MemoryLayout<GLubyte>.size)/MemoryLayout<GLubyte>.size),
                       GLenum(GL_UNSIGNED_BYTE), vertexBufferOffset)

        
        //描画
        _context!.presentRenderbuffer(Int(GL_RENDERBUFFER))
    }
    
    func setupVBOs() -> Int {
        var vertexBuffer = GLuint()
        //バッファオブジェクトの生成
        glGenBuffers(1, &vertexBuffer)
        //頂点バッファ用のバッファオブジェクトとしてバインド
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        //バッファに対してデータをアップロード
        glBufferData(GLenum(GL_ARRAY_BUFFER), (_vertices.count * MemoryLayout<Vertex>.size), _vertices, GLenum(GL_STATIC_DRAW))
        
        var indexBuffer = GLuint()
        glGenBuffers(1, &indexBuffer)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), (_indices.count * MemoryLayout<GLubyte>.size), _indices, GLenum(GL_STATIC_DRAW))
        return 0
    }
    
}

